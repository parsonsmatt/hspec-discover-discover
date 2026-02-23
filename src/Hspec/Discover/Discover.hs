{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StrictData #-}

-- | A GHC preprocessor that discovers hspec test modules. It finds both
-- a configurable file (default @Spec.hs@) in immediate subdirectories
-- (e.g. @test\/Foo\/Spec.hs@) and @*Spec.hs@ files in the same directory as
-- the entry point (e.g. @test\/FooSpec.hs@).
--
-- Intended to be used as a GHC preprocessor:
--
-- > {-# OPTIONS_GHC -F -pgmF hspec-discover-discover #-}
module Hspec.Discover.Discover
    ( run
    , configParser
    , configParserInfo
    , discover
    , extractPragmas
    , generate
    , validateResult
    , Config (..)
    , DiscoverResult (..)
    , GenerateParams (..)
    , InvalidDiscovery (..)
    ) where

import Control.Concurrent.Async (mapConcurrently)
import Data.Foldable (forM_)
import Data.List (isSuffixOf)
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Text.Lazy (Text)
import Data.Text.Lazy.Builder (Builder)
import qualified Data.Text.Lazy.Builder as TLB
import qualified Data.Text.Lazy.IO as TLIO
import Options.Applicative (Parser, ParserInfo)
import qualified Options.Applicative as Opts
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.Exit (exitFailure)
import System.FilePath (dropExtension, takeDirectory, (</>))
import System.IO (stderr)

-- | Preprocessor configuration, parsed from command-line arguments.
--
-- GHC passes three positional arguments to preprocessors: the original source
-- path, a temporary input path, and the output path. Additional options come
-- from @-optF@ flags.
data Config = Config
    { originalPath :: FilePath
    -- ^ The original source file path (e.g. @test\/Spec.hs@)
    , inputPath :: FilePath
    -- ^ Temporary input file path provided by GHC
    , outputPath :: FilePath
    -- ^ Output file path where generated code should be written
    , moduleName :: String
    -- ^ Module name for the generated file (default: @Main@)
    , subdirFile :: String
    -- ^ Filename to look for in subdirectories (default: @Spec.hs@)
    }
    deriving stock (Show, Eq)

-- | Result of scanning a directory for spec files.
data DiscoverResult = DiscoverResult
    { found :: Set.Set T.Text
    -- ^ Subdirectory names that contain the subdir file
    , foundLocal :: Set.Set T.Text
    -- ^ @*Spec.hs@ module names in the same directory, e.g. @["FooSpec"]@
    , missing :: Set.Set T.Text
    -- ^ Subdirectory names that do not contain the subdir file
    }
    deriving stock (Show, Eq)

instance Semigroup DiscoverResult where
    a <> b =
        DiscoverResult
            { found = found a <> found b
            , foundLocal = foundLocal a <> foundLocal b
            , missing = missing a <> missing b
            }

instance Monoid DiscoverResult where
    mempty = DiscoverResult{found = mempty, foundLocal = mempty, missing = mempty}

-- | Errors that can occur when validating discovery results.
data InvalidDiscovery
    = -- | No spec modules were found at all
      NoSpecsFound FilePath
    | -- | Some subdirectories are missing the configured spec file
      MissingSubdirSpecs FilePath String [T.Text]
    --                    dir     filename  subdirs
    deriving stock (Show, Eq)

-- | Validated discovery result ready for code generation.
-- Invariant: at least one of 'subdirSpecs' or 'localSpecs' is non-empty.
data GenerateParams = GenerateParams
    { subdirSpecs :: [T.Text]
    -- ^ Subdirectory names that contain the subdir file
    , localSpecs :: [T.Text]
    -- ^ Local @*Spec.hs@ module names
    , pragmas :: [T.Text]
    -- ^ Pragma lines extracted from the source file
    }
    deriving stock (Show, Eq)

-- | Validate a 'DiscoverResult', returning either an error or validated
-- parameters ready for code generation.
--
-- Fails if any subdirectory is missing the configured file ('MissingSubdirSpecs'),
-- or if no specs were found at all ('NoSpecsFound'). Missing subdirs take
-- priority over empty results.
validateResult :: FilePath -> String -> DiscoverResult -> Either InvalidDiscovery GenerateParams
validateResult dir subdirFilename result
    | not (Set.null (missing result)) =
        Left (MissingSubdirSpecs dir subdirFilename (Set.toAscList (missing result)))
    | Set.null (found result) && Set.null (foundLocal result) =
        Left (NoSpecsFound dir)
    | otherwise =
        Right
            GenerateParams
                { subdirSpecs = Set.toAscList (found result)
                , localSpecs = Set.toAscList (foundLocal result)
                , pragmas = []
                }

-- | Main entry point. Parses command-line arguments, discovers test modules,
-- and writes the generated Haskell source to the output file.
--
-- Warns on stderr for each subdirectory missing the configured subdir file,
-- and exits with failure if no test modules are found.
run :: IO ()
run = do
    config <- Opts.execParser configParserInfo
    let
        specDir = takeDirectory (originalPath config)
    result <- discover specDir (subdirFile config)
    case validateResult specDir (subdirFile config) result of
        Left (MissingSubdirSpecs dir filename dirs) -> do
            forM_ dirs $ \subdir ->
                warn $
                    mconcat
                        [ "hspec-discover-discover: "
                        , TLB.fromString dir
                        , "/"
                        , TLB.fromText subdir
                        , " is missing a "
                        , TLB.fromString filename
                        ]
            exitFailure
        Left (NoSpecsFound dir) -> do
            warn $
                "hspec-discover-discover: no spec modules found in "
                    <> TLB.fromString dir
            exitFailure
        Right params -> do
            sourceContent <- TIO.readFile (inputPath config)
            let userPragmas = extractPragmas sourceContent
            TLIO.writeFile (outputPath config) (generate config params{pragmas = userPragmas})

-- | 'ParserInfo' for use with @optparse-applicative@. Includes @--help@
-- support.
configParserInfo :: ParserInfo Config
configParserInfo = Opts.info (configParser Opts.<**> Opts.helper) Opts.fullDesc

-- | Command-line argument parser. Expects three positional arguments
-- (original path, input path, output path) and optional @--module-name@ and
-- @--subdir-file@ flags.
configParser :: Parser Config
configParser =
    Config
        <$> Opts.argument Opts.str (Opts.metavar "ORIGINAL_PATH")
        <*> Opts.argument Opts.str (Opts.metavar "INPUT_PATH")
        <*> Opts.argument Opts.str (Opts.metavar "OUTPUT_PATH")
        <*> Opts.option
            Opts.str
            ( Opts.long "module-name"
                <> Opts.value "Main"
                <> Opts.metavar "NAME"
                <> Opts.help "Module name for the generated file"
            )
        <*> Opts.option
            Opts.str
            ( Opts.long "subdir-file"
                <> Opts.value "Spec.hs"
                <> Opts.metavar "FILENAME"
                <> Opts.help "Filename to look for in subdirectories"
            )

-- | Scan a directory for test modules. Finds the given filename in immediate
-- subdirectories and @*Spec.hs@ files in the same directory. Filesystem
-- checks run concurrently.
discover :: FilePath -> String -> IO DiscoverResult
discover dir subdirFilename = do
    entries <- listDirectory dir
    mconcat <$> mapConcurrently classify entries
  where
    classify entry = do
        let name = T.pack entry
            entryPath = dir </> entry
        isDir <- doesDirectoryExist entryPath
        if isDir
            then do
                hasSpec <- doesFileExist (entryPath </> subdirFilename)
                pure $
                    if hasSpec
                        then mempty{found = Set.singleton name}
                        else mempty{missing = Set.singleton name}
            else
                pure $
                    if isLocalSpec entry
                        then mempty{foundLocal = Set.singleton (T.pack (dropExtension entry))}
                        else mempty

    -- Skip the first character so that "Spec.hs" itself is not matched.
    isLocalSpec (_ : rest) = "Spec.hs" `isSuffixOf` rest
    isLocalSpec _ = False

-- | Extract pragma lines from the top of a Haskell source file.
-- Returns lines containing @{-#@ and @#-}@, stopping at the @module@ line
-- or first non-pragma, non-blank line. Filters out the preprocessor invocation
-- pragma (any line containing @-pgmF@).
extractPragmas :: T.Text -> [T.Text]
extractPragmas =
    filter (not . T.isInfixOf "-pgmF")
        . takeWhile isPragma
        . filter (not . T.null . T.strip)
        . T.lines
  where
    isPragma l = T.isInfixOf "{-#" l && T.isInfixOf "#-}" l

-- | Generate Haskell source code that imports and runs the discovered test
-- modules. Each module is wrapped in a @describe@ block — subdirectory
-- modules use the directory name as the label, and local modules use the
-- module name with the @Spec@ suffix stripped. The subdirectory module name
-- is derived from 'subdirFile' (e.g. @SubTest.hs@ → @SubTest@).
--
-- When 'moduleName' is @Main@, a @main@ function is generated that calls
-- @hspec spec@. Otherwise, only @spec@ is exported.
generate :: Config -> GenerateParams -> Text
generate config params =
    TLB.toLazyText $
        mconcat
            [ line ("{-# LINE 1 " <> TLB.fromString (show (originalPath config)) <> " #-}")
            , foldMap (line . TLB.fromText) (pragmas params)
            , line "{-# OPTIONS_GHC -w #-}"
            , line ("module " <> TLB.fromString (moduleName config) <> " (" <> exports <> ") where")
            , newline
            , line "import Test.Hspec"
            , subdirImports
            , localImports
            , newline
            , mainDecl
            , line "spec :: Spec"
            , line "spec = do"
            , subdirDescribes
            , localDescribes
            ]
  where
    Pair subdirImports subdirDescribes = foldMap subdirEntry (subdirSpecs params)
    Pair localImports localDescribes = foldMap localEntry (localSpecs params)

    subdirEntry modName =
        Pair
            (line ("import qualified " <> TLB.fromText modName <> "." <> subdirMod))
            (line ("  describe " <> quoted modName <> " " <> TLB.fromText modName <> "." <> subdirMod <> ".spec"))

    localEntry modName =
        Pair
            (line ("import qualified " <> TLB.fromText modName))
            (line ("  describe " <> quoted (stripSpecSuffix modName) <> " " <> TLB.fromText modName <> ".spec"))

    subdirMod :: Builder
    subdirMod = TLB.fromString (dropExtension (subdirFile config))

    exports :: Builder
    exports
        | moduleName config == "Main" = "main"
        | otherwise = "spec"

    mainDecl
        | moduleName config == "Main" =
            mconcat
                [ line "main :: IO ()"
                , line "main = hspec spec"
                , newline
                ]
        | otherwise = mempty

    stripSpecSuffix :: T.Text -> T.Text
    stripSpecSuffix t = fromMaybe t (T.stripSuffix "Spec" t)

    quoted :: T.Text -> Builder
    quoted t = "\"" <> TLB.fromText t <> "\""

-- | Strict pair of 'Builder's, used to accumulate imports and describes
-- in a single pass without thunk buildup.
data Pair = Pair Builder Builder

instance Semigroup Pair where
    Pair a1 b1 <> Pair a2 b2 = Pair (a1 <> a2) (b1 <> b2)

instance Monoid Pair where
    mempty = Pair mempty mempty

line :: Builder -> Builder
line b = b <> TLB.singleton '\n'

newline :: Builder
newline = TLB.singleton '\n'

warn :: Builder -> IO ()
warn = TLIO.hPutStrLn stderr . TLB.toLazyText
