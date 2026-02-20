module Integration.Spec (spec) where

import Test.Hspec
import qualified Integration.IntegrationSpec

spec :: Spec
spec = do
    describe "Integration" Integration.IntegrationSpec.spec
