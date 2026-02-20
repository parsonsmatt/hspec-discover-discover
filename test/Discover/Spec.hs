{-# LANGUAGE OverloadedStrings #-}

module Discover.Spec (spec) where

import Test.Hspec

import System.Directory (createDirectory)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)

import Hspec.Discover.Discover

spec :: Spec
spec = do
    it "finds subdirectories containing Spec.hs" $
        withTestDir $ \dir -> do
            createSubdir dir "Foo"
            createSubdir dir "Bar"
            result <- discover dir "Spec.hs"
            found result `shouldBe` ["Bar", "Foo"]
            foundLocal result `shouldBe` []
            missing result `shouldBe` []

    it "reports subdirectories missing Spec.hs" $
        withTestDir $ \dir -> do
            createSubdir dir "Foo"
            createDirectory (dir </> "Baz")
            result <- discover dir "Spec.hs"
            found result `shouldBe` ["Foo"]
            missing result `shouldBe` ["Baz"]

    it "returns empty found when no subdirectory has Spec.hs" $
        withTestDir $ \dir -> do
            createDirectory (dir </> "Baz")
            result <- discover dir "Spec.hs"
            found result `shouldBe` []
            missing result `shouldBe` ["Baz"]

    it "ignores non-directory entries" $
        withTestDir $ \dir -> do
            createSubdir dir "Foo"
            writeFile (dir </> "README.md") ""
            result <- discover dir "Spec.hs"
            found result `shouldBe` ["Foo"]
            missing result `shouldBe` []

    it "returns results sorted" $
        withTestDir $ \dir -> do
            createSubdir dir "Zebra"
            createSubdir dir "Alpha"
            createSubdir dir "Middle"
            result <- discover dir "Spec.hs"
            found result `shouldBe` ["Alpha", "Middle", "Zebra"]

    it "finds *Spec.hs files in the same directory" $
        withTestDir $ \dir -> do
            writeFile (dir </> "FooSpec.hs") ""
            writeFile (dir </> "BarSpec.hs") ""
            result <- discover dir "Spec.hs"
            foundLocal result `shouldBe` ["BarSpec", "FooSpec"]

    it "excludes Spec.hs from local specs" $
        withTestDir $ \dir -> do
            writeFile (dir </> "Spec.hs") ""
            writeFile (dir </> "FooSpec.hs") ""
            result <- discover dir "Spec.hs"
            foundLocal result `shouldBe` ["FooSpec"]

    it "ignores non-spec .hs files" $
        withTestDir $ \dir -> do
            writeFile (dir </> "Helper.hs") ""
            writeFile (dir </> "FooSpec.hs") ""
            result <- discover dir "Spec.hs"
            foundLocal result `shouldBe` ["FooSpec"]

    it "ignores *Spec.hs files starting with lowercase" $
        withTestDir $ \dir -> do
            writeFile (dir </> "fooSpec.hs") ""
            writeFile (dir </> "FooSpec.hs") ""
            result <- discover dir "Spec.hs"
            foundLocal result `shouldBe` ["FooSpec"]

    it "finds both subdirectory and local specs" $
        withTestDir $ \dir -> do
            createSubdir dir "Foo"
            writeFile (dir </> "BarSpec.hs") ""
            result <- discover dir "Spec.hs"
            found result `shouldBe` ["Foo"]
            foundLocal result `shouldBe` ["BarSpec"]

    it "finds subdirectories with custom subdir file" $
        withTestDir $ \dir -> do
            createDirectory (dir </> "Foo")
            writeFile (dir </> "Foo" </> "SubTest.hs") "module Foo.SubTest where"
            createDirectory (dir </> "Bar")
            writeFile (dir </> "Bar" </> "Spec.hs") "module Bar.Spec where"
            result <- discover dir "SubTest.hs"
            found result `shouldBe` ["Foo"]
            missing result `shouldBe` ["Bar"]

withTestDir :: (FilePath -> IO a) -> IO a
withTestDir = withSystemTempDirectory "hspec-discover-discover-test"

createSubdir :: FilePath -> String -> IO ()
createSubdir dir name = do
    createDirectory (dir </> name)
    writeFile (dir </> name </> "Spec.hs") $ "module " ++ name ++ ".Spec where"
