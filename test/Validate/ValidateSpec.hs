{-# LANGUAGE OverloadedStrings #-}

module Validate.ValidateSpec (spec) where

import Test.Hspec

import qualified Data.Set as Set

import Hspec.Discover.Discover

spec :: Spec
spec = do
    describe "validateResult" $ do
        it "returns Right when subdirs found, no missing" $ do
            validateResult "test" "Spec.hs" DiscoverResult{found = Set.fromList ["Foo", "Bar"], foundLocal = Set.empty, missing = Set.empty}
                `shouldBe` Right GenerateParams{subdirSpecs = ["Bar", "Foo"], localSpecs = [], pragmas = []}

        it "returns Right when only local specs found" $ do
            validateResult "test" "Spec.hs" DiscoverResult{found = Set.empty, foundLocal = Set.fromList ["FooSpec", "BarSpec"], missing = Set.empty}
                `shouldBe` Right GenerateParams{subdirSpecs = [], localSpecs = ["BarSpec", "FooSpec"], pragmas = []}

        it "returns Right when both subdirs and local specs found" $ do
            validateResult "test" "Spec.hs" DiscoverResult{found = Set.fromList ["Foo"], foundLocal = Set.fromList ["BarSpec"], missing = Set.empty}
                `shouldBe` Right GenerateParams{subdirSpecs = ["Foo"], localSpecs = ["BarSpec"], pragmas = []}

        it "returns Left MissingSubdirSpecs when any subdir is missing its file" $ do
            validateResult "test" "Spec.hs" DiscoverResult{found = Set.empty, foundLocal = Set.empty, missing = Set.fromList ["Baz"]}
                `shouldBe` Left (MissingSubdirSpecs "test" "Spec.hs" ["Baz"])

        it "returns Left MissingSubdirSpecs even when some subdirs are found" $ do
            validateResult "test" "Spec.hs" DiscoverResult{found = Set.fromList ["Foo"], foundLocal = Set.empty, missing = Set.fromList ["Baz"]}
                `shouldBe` Left (MissingSubdirSpecs "test" "Spec.hs" ["Baz"])

        it "returns Left NoSpecsFound when nothing discovered at all" $ do
            validateResult "test" "Spec.hs" DiscoverResult{found = Set.empty, foundLocal = Set.empty, missing = Set.empty}
                `shouldBe` Left (NoSpecsFound "test")

        it "does not fail when local specs are absent but subdirs exist" $ do
            validateResult "test" "Spec.hs" DiscoverResult{found = Set.fromList ["Foo"], foundLocal = Set.empty, missing = Set.empty}
                `shouldBe` Right GenerateParams{subdirSpecs = ["Foo"], localSpecs = [], pragmas = []}
