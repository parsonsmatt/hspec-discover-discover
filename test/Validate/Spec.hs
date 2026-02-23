module Validate.Spec (spec) where

import Test.Hspec

import qualified Validate.ValidateSpec

spec :: Spec
spec = do
    describe "Validate" Validate.ValidateSpec.spec
