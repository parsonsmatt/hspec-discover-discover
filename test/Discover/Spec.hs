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

withTestDir :: (FilePath -> IO a) -> IO a
withTestDir = withSystemTempDirectory "hspec-discover-discover-test"

createSubdir :: FilePath -> String -> IO ()
createSubdir dir name = do
    createDirectory (dir </> name)
    writeFile (dir </> name </> "Spec.hs") $ "module " ++ name ++ ".Spec where"
