# hspec-discover-discover

A GHC preprocessor for [hspec](https://hspec.github.io/) that discovers test
modules in **immediate subdirectories** and **co-located `*Spec.hs` files**.

Unlike `hspec-discover`, which recursively finds all `*Spec.hs` files,
`hspec-discover-discover` looks for:

- `Spec.hs` files in immediate subdirectories (e.g. `test/Foo/Spec.hs`)
- `*Spec.hs` files in the same directory as the entry point (e.g. `test/FooSpec.hs`)

This gives you explicit control over test organization — each subdirectory or
spec file is a top-level test group.

## Usage

In your `test/Spec.hs`:

```haskell
{-# OPTIONS_GHC -F -pgmF hspec-discover-discover #-}
```

Then organize your tests as subdirectories containing `Spec.hs`, or as
`*Spec.hs` files alongside the entry point:

```
test/
  Spec.hs                -- preprocessor entry point (the line above)
  FooSpec.hs             -- module FooSpec, exports spec :: Spec
  ParseArgs/
    Spec.hs              -- module ParseArgs.Spec, exports spec :: Spec
  Discover/
    Spec.hs              -- module Discover.Spec, exports spec :: Spec
  Generate/
    Spec.hs              -- module Generate.Spec, exports spec :: Spec
```

Each module should export a `spec :: Spec`:

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
import qualified FooSpec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Discover" Discover.Spec.spec
  describe "Generate" Generate.Spec.spec
  describe "ParseArgs" ParseArgs.Spec.spec
  describe "Foo" FooSpec.spec
```

### Options

Pass options via `-optF` in your GHC options:

- `--module-name=NAME` — Set the generated module name (default: `Main`).
  When the module name is not `Main`, the `main` function is omitted and only
  `spec` is exported.

### Missing specs

If a subdirectory does not contain a `Spec.hs`, a warning is printed to stderr.
If no spec modules are found at all, the preprocessor exits with an error.

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
| Discovery | Recursive `*Spec.hs` | Immediate subdirs with `Spec.hs` + co-located `*Spec.hs` |
| Naming | Any file ending in `Spec.hs` | `Spec.hs` in subdirs, or `*Spec.hs` in same directory |
| Grouping | Flat list of specs | One `describe` per subdirectory or local spec |

## License

BSD-3-Clause
