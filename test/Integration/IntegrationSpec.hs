{-# LANGUAGE OverloadedStrings #-}

module Integration.IntegrationSpec (spec) where

import Test.Hspec

import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, (</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)

-- | Compile a Haskell file with GHC, returning (exitCode, stderr).
-- Assumes GHC is on PATH (true when running via @stack test@ or @cabal test@).
compileWithGhc :: FilePath -> [String] -> IO (ExitCode, String)
compileWithGhc hsFile extraFlags = do
    (exitCode, _stdout, stderr) <-
        readProcessWithExitCode
            "ghc"
            ( ["-fno-code", "-i" <> takeDirectory hsFile]
                <> extraFlags
                <> [hsFile]
            )
            ""
    pure (exitCode, stderr)

spec :: Spec
spec = do
    it "-w suppresses -Wprepositive-qualified-module under -Werror" $ do
        withSystemTempDirectory "hspec-discover-discover-integration" $ \dir -> do
            let hsFile = dir </> "Test.hs"
            writeFile hsFile $
                unlines
                    [ "{-# OPTIONS_GHC -w #-}"
                    , "module Test where"
                    , "import qualified Data.List"
                    ]
            (exitCode, stderr) <- compileWithGhc hsFile ["-Werror", "-Wprepositive-qualified-module"]
            case exitCode of
                ExitSuccess -> pure ()
                ExitFailure _ -> expectationFailure $ "GHC compilation failed:\n" <> stderr

    it "user pragmas followed by -w suppresses warnings under -Werror" $ do
        withSystemTempDirectory "hspec-discover-discover-integration" $ \dir -> do
            let hsFile = dir </> "Test.hs"
            writeFile hsFile $
                unlines
                    [ "{-# OPTIONS_GHC -O0 #-}"
                    , "{-# OPTIONS_GHC -fno-warn-deprecations -Wwarn #-}"
                    , "{-# OPTIONS_GHC -w #-}"
                    , "module Test where"
                    , "import qualified Data.List"
                    ]
            (exitCode, stderr) <- compileWithGhc hsFile ["-Werror", "-Wall", "-Wprepositive-qualified-module"]
            case exitCode of
                ExitSuccess -> pure ()
                ExitFailure _ -> expectationFailure $ "GHC compilation failed:\n" <> stderr

    it "without -w, -Wprepositive-qualified-module fires under -Werror" $ do
        withSystemTempDirectory "hspec-discover-discover-integration" $ \dir -> do
            let hsFile = dir </> "Test.hs"
            writeFile hsFile $
                unlines
                    [ "module Test where"
                    , "import qualified Data.List"
                    ]
            (exitCode, _stderr) <- compileWithGhc hsFile ["-Werror", "-Wprepositive-qualified-module"]
            exitCode `shouldBe` ExitFailure 1
