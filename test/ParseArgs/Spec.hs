module ParseArgs.Spec (spec) where

import Test.Hspec

import Options.Applicative (defaultPrefs, execParserPure, getParseResult)

import Hspec.Discover.Discover

parseArgs :: [String] -> Maybe Config
parseArgs = getParseResult . execParserPure defaultPrefs configParserInfo

spec :: Spec
spec = do
    it "parses three positional args with default config" $ do
        case parseArgs ["a", "b", "c"] of
            Nothing -> expectationFailure "expected successful parse"
            Just config -> do
                originalPath config `shouldBe` "a"
                inputPath config `shouldBe` "b"
                outputPath config `shouldBe` "c"
                moduleName config `shouldBe` "Main"

    it "parses --module-name flag" $ do
        case parseArgs ["a", "b", "c", "--module-name=MySpec"] of
            Nothing -> expectationFailure "expected successful parse"
            Just config -> moduleName config `shouldBe` "MySpec"

    it "parses --module-name flag with space" $ do
        case parseArgs ["a", "b", "c", "--module-name", "MySpec"] of
            Nothing -> expectationFailure "expected successful parse"
            Just config -> moduleName config `shouldBe` "MySpec"

    it "fails with too few args" $ do
        parseArgs ["a", "b"] `shouldBe` Nothing
