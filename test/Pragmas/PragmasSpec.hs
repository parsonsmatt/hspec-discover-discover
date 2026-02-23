{-# LANGUAGE OverloadedStrings #-}

module Pragmas.PragmasSpec (spec) where

import Test.Hspec

import qualified Data.Text as T

import Hspec.Discover.Discover (extractPragmas)

spec :: Spec
spec = do
    it "extracts LANGUAGE pragmas" $ do
        extractPragmas "{-# LANGUAGE OverloadedStrings #-}\nmodule Foo where\n"
            `shouldBe` ["{-# LANGUAGE OverloadedStrings #-}"]

    it "extracts OPTIONS_GHC pragmas" $ do
        extractPragmas "{-# OPTIONS_GHC -Wall #-}\nmodule Foo where\n"
            `shouldBe` ["{-# OPTIONS_GHC -Wall #-}"]

    it "filters out -pgmF pragma" $ do
        extractPragmas "{-# LANGUAGE OverloadedStrings #-}\n{-# OPTIONS_GHC -F -pgmF hspec-discover-discover #-}\nmodule Foo where\n"
            `shouldBe` ["{-# LANGUAGE OverloadedStrings #-}"]

    it "returns empty list when no pragmas" $ do
        extractPragmas "module Foo where\n"
            `shouldBe` []

    it "stops at module line" $ do
        extractPragmas "{-# LANGUAGE GADTs #-}\nmodule Foo where\n{-# LANGUAGE TypeFamilies #-}\n"
            `shouldBe` ["{-# LANGUAGE GADTs #-}"]

    it "handles multiple pragmas" $ do
        extractPragmas "{-# LANGUAGE OverloadedStrings #-}\n{-# LANGUAGE GADTs #-}\n{-# OPTIONS_GHC -Wall #-}\nmodule Foo where\n"
            `shouldBe` ["{-# LANGUAGE OverloadedStrings #-}", "{-# LANGUAGE GADTs #-}", "{-# OPTIONS_GHC -Wall #-}"]

    it "skips blank lines between pragmas" $ do
        extractPragmas "{-# LANGUAGE GADTs #-}\n\n{-# LANGUAGE TypeFamilies #-}\nmodule Foo where\n"
            `shouldBe` ["{-# LANGUAGE GADTs #-}", "{-# LANGUAGE TypeFamilies #-}"]

    it "keeps warning pragmas and filters pgmF from real-world header" $ do
        let
            input =
                T.unlines
                    [ "{-# OPTIONS_GHC -F -pgmF hspec-discover-discover -optF --module-name=Spec -optF --subdir-file=TestGroup.hs #-}"
                    , "{-# OPTIONS_GHC -O0 #-}"
                    , "{-# OPTIONS_GHC -fno-warn-deprecations -Wwarn -fno-warn-prepositive-qualified-module #-}"
                    ]
        extractPragmas input
            `shouldBe`
                [ "{-# OPTIONS_GHC -O0 #-}"
                , "{-# OPTIONS_GHC -fno-warn-deprecations -Wwarn -fno-warn-prepositive-qualified-module #-}"
                ]
