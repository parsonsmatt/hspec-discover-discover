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
            result <- discover dir
            found result `shouldBe` ["Bar", "Foo"]
            foundLocal result `shouldBe` []
            missing result `shouldBe` []

    it "reports subdirectories missing Spec.hs" $
        withTestDir $ \dir -> do
            createSubdir dir "Foo"
            createDirectory (dir </> "Baz")
            result <- discover dir
            found result `shouldBe` ["Foo"]
            missing result `shouldBe` ["Baz"]

    it "returns empty found when no subdirectory has Spec.hs" $
        withTestDir $ \dir -> do
            createDirectory (dir </> "Baz")
            result <- discover dir
            found result `shouldBe` []
            missing result `shouldBe` ["Baz"]

    it "ignores non-directory entries" $
        withTestDir $ \dir -> do
            createSubdir dir "Foo"
            writeFile (dir </> "README.md") ""
            result <- discover dir
            found result `shouldBe` ["Foo"]
            missing result `shouldBe` []

    it "returns results sorted" $
        withTestDir $ \dir -> do
            createSubdir dir "Zebra"
            createSubdir dir "Alpha"
            createSubdir dir "Middle"
            result <- discover dir
            found result `shouldBe` ["Alpha", "Middle", "Zebra"]

    it "finds *Spec.hs files in the same directory" $
        withTestDir $ \dir -> do
            writeFile (dir </> "FooSpec.hs") ""
            writeFile (dir </> "BarSpec.hs") ""
            result <- discover dir
            foundLocal result `shouldBe` ["BarSpec", "FooSpec"]

    it "excludes Spec.hs from local specs" $
        withTestDir $ \dir -> do
            writeFile (dir </> "Spec.hs") ""
            writeFile (dir </> "FooSpec.hs") ""
            result <- discover dir
            foundLocal result `shouldBe` ["FooSpec"]

    it "ignores non-spec .hs files" $
        withTestDir $ \dir -> do
            writeFile (dir </> "Helper.hs") ""
            writeFile (dir </> "FooSpec.hs") ""
            result <- discover dir
            foundLocal result `shouldBe` ["FooSpec"]

    it "finds both subdirectory and local specs" $
        withTestDir $ \dir -> do
            createSubdir dir "Foo"
            writeFile (dir </> "BarSpec.hs") ""
            result <- discover dir
            found result `shouldBe` ["Foo"]
            foundLocal result `shouldBe` ["BarSpec"]

withTestDir :: (FilePath -> IO a) -> IO a
withTestDir = withSystemTempDirectory "hspec-discover-discover-test"

createSubdir :: FilePath -> String -> IO ()
createSubdir dir name = do
    createDirectory (dir </> name)
    writeFile (dir </> name </> "Spec.hs") $ "module " ++ name ++ ".Spec where"
