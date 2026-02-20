{-# LANGUAGE OverloadedStrings #-}

module Generate.GenerateSpec (spec) where

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
        , subdirFile = "Spec.hs"
        }

spec :: Spec
spec = do
    it "generates correct output for Main module" $ do
        let
            output = generate defaultConfig (DiscoverResult ["Bar", "Foo"] [] [])
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
            output = generate defaultConfig{moduleName = "MySpec"} (DiscoverResult ["Foo"] [] [])
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
            output = generate defaultConfig{originalPath = "some/path/Spec.hs"} (DiscoverResult ["Foo"] [] [])
        output `shouldSatisfy` isInfixOf (pack "{-# LINE 1 \"some/path/Spec.hs\" #-}")

    it "generates imports and describes for local specs" $ do
        let
            output = generate defaultConfig (DiscoverResult [] ["BarSpec", "FooSpec"] [])
        output
            `shouldBe` unlines
                [ "{-# LINE 1 \"test/Spec.hs\" #-}"
                , "module Main (main) where"
                , ""
                , "import Test.Hspec"
                , "import qualified BarSpec"
                , "import qualified FooSpec"
                , ""
                , "main :: IO ()"
                , "main = hspec spec"
                , ""
                , "spec :: Spec"
                , "spec = do"
                , "  describe \"Bar\" BarSpec.spec"
                , "  describe \"Foo\" FooSpec.spec"
                ]

    it "generates output for both subdirectory and local specs" $ do
        let
            output = generate defaultConfig (DiscoverResult ["Sub"] ["LocalSpec"] [])
        output
            `shouldBe` unlines
                [ "{-# LINE 1 \"test/Spec.hs\" #-}"
                , "module Main (main) where"
                , ""
                , "import Test.Hspec"
                , "import qualified Sub.Spec"
                , "import qualified LocalSpec"
                , ""
                , "main :: IO ()"
                , "main = hspec spec"
                , ""
                , "spec :: Spec"
                , "spec = do"
                , "  describe \"Sub\" Sub.Spec.spec"
                , "  describe \"Local\" LocalSpec.spec"
                ]

    it "generates imports using custom subdir file" $ do
        let
            output = generate defaultConfig{subdirFile = "SubTest.hs"} (DiscoverResult ["Foo"] [] [])
        output
            `shouldBe` unlines
                [ "{-# LINE 1 \"test/Spec.hs\" #-}"
                , "module Main (main) where"
                , ""
                , "import Test.Hspec"
                , "import qualified Foo.SubTest"
                , ""
                , "main :: IO ()"
                , "main = hspec spec"
                , ""
                , "spec :: Spec"
                , "spec = do"
                , "  describe \"Foo\" Foo.SubTest.spec"
                ]
