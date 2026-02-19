module Generate.Spec (spec) where

import Test.Hspec
import qualified Generate.GenerateSpec

spec :: Spec
spec = do
    describe "Generate" Generate.GenerateSpec.spec
