{-# LANGUAGE OverloadedStrings #-}

module Generate.Spec (spec) where

import Test.Hspec

import Data.Text.Lazy (isInfixOf, pack, unlines)
import Prelude hiding (unlines)

import Hspec.Discover.Discover

defaultConfig :: Config
defaultConfig =
    Config
        { originalPath = "test/Spec.hs"
        , inputPath = "test/Spec.hs"
        , outputPath = "test/Spec.hs"
        , moduleName = "Main"
        }

spec :: Spec
spec = do
    it "generates correct output for Main module" $ do
        let
            output = generate defaultConfig ["Bar", "Foo"]
        output
            `shouldBe` unlines
                [ "{-# LINE 1 \"test/Spec.hs\" #-}"
                , "module Main (main) where"
                , ""
                , "import Test.Hspec"
                , "import qualified Bar.Spec"
                , "import qualified Foo.Spec"
                , ""
                , "main :: IO ()"
                , "main = hspec spec"
                , ""
                , "spec :: Spec"
                , "spec = do"
                , "  describe \"Bar\" Bar.Spec.spec"
                , "  describe \"Foo\" Foo.Spec.spec"
                ]

    it "omits main when module name is not Main" $ do
        let
            output = generate defaultConfig{moduleName = "MySpec"} ["Foo"]
        output
            `shouldBe` unlines
                [ "{-# LINE 1 \"test/Spec.hs\" #-}"
                , "module MySpec (spec) where"
                , ""
                , "import Test.Hspec"
                , "import qualified Foo.Spec"
                , ""
                , "spec :: Spec"
                , "spec = do"
                , "  describe \"Foo\" Foo.Spec.spec"
                ]

    it "includes LINE pragma with original path" $ do
        let
            output = generate defaultConfig{originalPath = "some/path/Spec.hs"} ["Foo"]
        output `shouldSatisfy` isInfixOf (pack "{-# LINE 1 \"some/path/Spec.hs\" #-}")
