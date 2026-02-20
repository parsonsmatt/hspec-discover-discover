{-# LANGUAGE OverloadedStrings #-}

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
    , generate
    , Config (..)
    , DiscoverResult (..)
    ) where

import Data.Char (isUpper)
import Data.List (sort)
import qualified Data.Text as T
import Data.Text.Lazy (Text)
import Data.Text.Lazy.Builder (Builder)
import qualified Data.Text.Lazy.Builder as TLB
import qualified Data.Text.Lazy.IO as TL
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
    deriving (Show, Eq)

-- | Result of scanning a directory for spec files.
data DiscoverResult = DiscoverResult
    { found :: [T.Text]
    -- ^ Subdirectory names that contain the subdir file (sorted)
    , foundLocal :: [T.Text]
    -- ^ @*Spec.hs@ module names in the same directory (sorted), e.g. @["FooSpec"]@
    , missing :: [T.Text]
    -- ^ Subdirectory names that do not contain the subdir file (sorted)
    }
    deriving (Show, Eq)

-- | Main entry point. Parses command-line arguments, discovers test modules,
-- and writes the generated Haskell source to the output file.
--
-- Warns on stderr for each subdirectory missing the configured subdir file,
-- and exits with failure if no test modules are found.
run :: IO ()
run = do
    config <- Opts.execParser configParserInfo
    let
        dir = takeDirectory (originalPath config)
    result <- discover dir (subdirFile config)
    mapM_
        ( \d ->
            warn $
                "hspec-discover-discover: "
                    <> TLB.fromString dir
                    <> "/"
                    <> TLB.fromText d
                    <> " is missing a "
                    <> TLB.fromString (subdirFile config)
        )
        (missing result)
    if null (found result) && null (foundLocal result)
        then do
            warn $
                "hspec-discover-discover: no spec modules found in "
                    <> TLB.fromString dir
            exitFailure
        else
            TL.writeFile (outputPath config) (generate config result)

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
-- subdirectories and @*Spec.hs@ files (with uppercase first letter) in the
-- directory itself. Returns found, local, and missing names, sorted
-- alphabetically.
discover :: FilePath -> String -> IO DiscoverResult
discover dir subdirFilename = do
    entries <- listDirectory dir
    go (DiscoverResult [] [] []) entries
  where
    go result [] =
        pure
            result
                { found = sort (found result)
                , foundLocal = sort (foundLocal result)
                , missing = sort (missing result)
                }
    go result (e : es) = do
        isDir <- doesDirectoryExist (dir </> e)
        if isDir
            then do
                hasSpec <- doesFileExist (dir </> e </> subdirFilename)
                if hasSpec
                    then go result{found = T.pack e : found result} es
                    else go result{missing = T.pack e : missing result} es
            else
                if isLocalSpec e
                    then go result{foundLocal = T.pack (dropExtension e) : foundLocal result} es
                    else go result es

    isLocalSpec (c : rest) = isUpper c && T.isSuffixOf "Spec.hs" (T.pack rest)
    isLocalSpec _ = False

-- | Generate Haskell source code that imports and runs the discovered test
-- modules. Each module is wrapped in a @describe@ block — subdirectory
-- modules use the directory name as the label, and local modules use the
-- module name with the @Spec@ suffix stripped. The subdirectory module name
-- is derived from 'subdirFile' (e.g. @SubTest.hs@ → @SubTest@).
--
-- When 'moduleName' is @Main@, a @main@ function is generated that calls
-- @hspec spec@. Otherwise, only @spec@ is exported.
generate :: Config -> DiscoverResult -> Text
generate config result =
    TLB.toLazyText $
        line ("{-# LINE 1 " <> TLB.fromString (show (originalPath config)) <> " #-}")
            <> line
                ("module " <> TLB.fromString (moduleName config) <> " (" <> exports <> ") where")
            <> newline
            <> line "import Test.Hspec"
            <> foldMap
                (\m -> line ("import qualified " <> TLB.fromText m <> "." <> subdirMod))
                (found result)
            <> foldMap
                (\m -> line ("import qualified " <> TLB.fromText m))
                (foundLocal result)
            <> newline
            <> mainDecl
            <> line "spec :: Spec"
            <> line "spec = do"
            <> foldMap
                ( \m ->
                    line
                        ( "  describe "
                            <> quoted m
                            <> " "
                            <> TLB.fromText m
                            <> "."
                            <> subdirMod
                            <> ".spec"
                        )
                )
                (found result)
            <> foldMap
                ( \m ->
                    line
                        ( "  describe "
                            <> quoted (stripSpecSuffix m)
                            <> " "
                            <> TLB.fromText m
                            <> ".spec"
                        )
                )
                (foundLocal result)
  where
    subdirMod :: Builder
    subdirMod = TLB.fromString (dropExtension (subdirFile config))

    exports :: Builder
    exports
        | moduleName config == "Main" = "main"
        | otherwise = "spec"

    mainDecl
        | moduleName config == "Main" =
            line "main :: IO ()"
                <> line "main = hspec spec"
                <> newline
        | otherwise = mempty

    stripSpecSuffix :: T.Text -> T.Text
    stripSpecSuffix t = maybe t id (T.stripSuffix "Spec" t)

    quoted :: T.Text -> Builder
    quoted t = "\"" <> TLB.fromText t <> "\""

line :: Builder -> Builder
line b = b <> TLB.singleton '\n'

newline :: Builder
newline = TLB.singleton '\n'

warn :: Builder -> IO ()
warn = TL.hPutStrLn stderr . TLB.toLazyText
