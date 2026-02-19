# hspec-discover-discover

A GHC preprocessor for [hspec](https://hspec.github.io/) that discovers test
modules in **immediate subdirectories** only.

Unlike `hspec-discover`, which recursively finds all `*Spec.hs` files,
`hspec-discover-discover` looks for files named `Spec.hs` in the immediate
subdirectories of your test directory. This gives you explicit control over test
organization — each subdirectory is a top-level test group.

## Usage

In your `test/Spec.hs`:

```haskell
{-# OPTIONS_GHC -F -pgmF hspec-discover-discover #-}
```

Then organize your tests as subdirectories, each containing a `Spec.hs`:

```
test/
  Spec.hs                -- preprocessor entry point (the line above)
  ParseArgs/
    Spec.hs              -- module ParseArgs.Spec, exports spec :: Spec
  Discover/
    Spec.hs              -- module Discover.Spec, exports spec :: Spec
  Generate/
    Spec.hs              -- module Generate.Spec, exports spec :: Spec
```

Each `Spec.hs` module should export a `spec :: Spec`:

```haskell
module ParseArgs.Spec (spec) where

import Test.Hspec

spec :: Spec
spec = do
    it "does something" $ do
        True `shouldBe` True
```

### Generated output

For the directory structure above, `hspec-discover-discover` generates:

```haskell
{-# LINE 1 "test/Spec.hs" #-}
module Main (main) where

import Test.Hspec
import qualified Discover.Spec
import qualified Generate.Spec
import qualified ParseArgs.Spec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Discover" Discover.Spec.spec
  describe "Generate" Generate.Spec.spec
  describe "ParseArgs" ParseArgs.Spec.spec
```

### Options

Pass options via `-optF` in your GHC options:

- `--module-name=NAME` — Set the generated module name (default: `Main`).
  When the module name is not `Main`, the `main` function is omitted and only
  `spec` is exported.

### Missing specs

If a subdirectory does not contain a `Spec.hs`, a warning is printed to stderr.
If no subdirectories contain a `Spec.hs`, the preprocessor exits with an error.

## Installation

Add `hspec-discover-discover` to your `package.yaml` or `.cabal` file as a
build tool dependency for your test suite:

```yaml
tests:
  my-test-suite:
    main: Spec.hs
    source-dirs: test
    build-tools:
    - hspec-discover-discover
    dependencies:
    - hspec
```

## Comparison with hspec-discover

| Feature | hspec-discover | hspec-discover-discover |
|---|---|---|
| Discovery | Recursive `*Spec.hs` | Immediate subdirs with `Spec.hs` |
| Naming | Any file ending in `Spec.hs` | Must be exactly `Spec.hs` |
| Grouping | Flat list of specs | One `describe` per subdirectory |

## License

BSD-3-Clause
