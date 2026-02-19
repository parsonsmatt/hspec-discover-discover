{-# LANGUAGE OverloadedStrings #-}

-- | A GHC preprocessor that discovers hspec test modules in immediate
-- subdirectories. Unlike @hspec-discover@, which recursively finds all
-- @*Spec.hs@ files, this tool looks for files named @Spec.hs@ in the
-- immediate subdirectories of the source file's directory.
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

import Data.List (sort)
import Data.Text.Lazy (Text)
import Data.Text.Lazy.Builder (Builder)
import qualified Data.Text.Lazy.Builder as TLB
import qualified Data.Text.Lazy.IO as TL
import Options.Applicative (Parser, ParserInfo)
import qualified Options.Applicative as Opts
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.Exit (exitFailure)
import System.FilePath (takeDirectory, (</>))
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
    }
    deriving (Show, Eq)

-- | Result of scanning a directory for @Spec.hs@ files.
data DiscoverResult = DiscoverResult
    { found :: [String]
    -- ^ Subdirectory names that contain a @Spec.hs@ (sorted)
    , missing :: [String]
    -- ^ Subdirectory names that do not contain a @Spec.hs@ (sorted)
    }
    deriving (Show, Eq)

-- | Main entry point. Parses command-line arguments, discovers test modules,
-- and writes the generated Haskell source to the output file.
--
-- Warns on stderr for each subdirectory missing a @Spec.hs@, and exits with
-- failure if no test modules are found.
run :: IO ()
run = do
    config <- Opts.execParser configParserInfo
    let
        dir = takeDirectory (originalPath config)
    result <- discover dir
    mapM_
        ( \d ->
            warn $
                "hspec-discover-discover: "
                    <> TLB.fromString (dir </> d)
                    <> " is missing a Spec.hs"
        )
        (missing result)
    case found result of
        [] -> do
            warn $
                "hspec-discover-discover: no Spec.hs found in subdirectories of "
                    <> TLB.fromString dir
            exitFailure
        modules ->
            TL.writeFile (outputPath config) (generate config modules)

-- | 'ParserInfo' for use with @optparse-applicative@. Includes @--help@
-- support.
configParserInfo :: ParserInfo Config
configParserInfo = Opts.info (configParser Opts.<**> Opts.helper) Opts.fullDesc

-- | Command-line argument parser. Expects three positional arguments
-- (original path, input path, output path) and an optional @--module-name@
-- flag.
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

-- | Scan a directory for immediate subdirectories containing @Spec.hs@.
-- Returns both the found and missing subdirectory names, sorted
-- alphabetically. Non-directory entries are ignored.
discover :: FilePath -> IO DiscoverResult
discover dir = do
    entries <- listDirectory dir
    go (DiscoverResult [] []) entries
  where
    go result [] = pure result{found = sort (found result), missing = sort (missing result)}
    go result (e : es) = do
        isDir <- doesDirectoryExist (dir </> e)
        if isDir
            then do
                hasSpec <- doesFileExist (dir </> e </> "Spec.hs")
                if hasSpec
                    then go result{found = e : found result} es
                    else go result{missing = e : missing result} es
            else go result es

-- | Generate Haskell source code that imports and runs the discovered test
-- modules. Each module is wrapped in a @describe@ block using the
-- subdirectory name as the label.
--
-- When 'moduleName' is @Main@, a @main@ function is generated that calls
-- @hspec spec@. Otherwise, only @spec@ is exported.
generate :: Config -> [String] -> Text
generate config modules =
    TLB.toLazyText $
        line ("{-# LINE 1 " <> TLB.fromString (show (originalPath config)) <> " #-}")
            <> line
                ("module " <> TLB.fromString (moduleName config) <> " (" <> exports <> ") where")
            <> newline
            <> line "import Test.Hspec"
            <> foldMap
                (\m -> line ("import qualified " <> TLB.fromString m <> ".Spec"))
                modules
            <> newline
            <> mainDecl
            <> line "spec :: Spec"
            <> line "spec = do"
            <> foldMap
                ( \m ->
                    line
                        ( "  describe "
                            <> TLB.fromString (show m)
                            <> " "
                            <> TLB.fromString m
                            <> ".Spec.spec"
                        )
                )
                modules
  where
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

line :: Builder -> Builder
line b = b <> TLB.singleton '\n'

newline :: Builder
newline = TLB.singleton '\n'

warn :: Builder -> IO ()
warn = TL.hPutStrLn stderr . TLB.toLazyText
