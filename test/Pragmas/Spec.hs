module Pragmas.Spec (spec) where

import Test.Hspec
import qualified Pragmas.PragmasSpec

spec :: Spec
spec = do
    describe "Pragmas" Pragmas.PragmasSpec.spec
