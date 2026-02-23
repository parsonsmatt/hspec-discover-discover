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

This file can itself be generated from `hspec-discover`, though you will need [this patch](https://github.com/hspec/hspec/pull/954) for it to generate modules properly in subdirectories.

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
- `--subdir-file=FILENAME` — Set the filename to look for in subdirectories
  (default: `Spec.hs`). This is useful when other tooling globs on `*Spec.hs`
  and interferes with the subdirectory entry points. Only affects subdirectory
  lookup — co-located `*Spec.hs` discovery is unchanged.

For example, to look for `SubTest.hs` instead of `Spec.hs` in subdirectories:

```haskell
{-# OPTIONS_GHC -F -pgmF hspec-discover-discover -optF --subdir-file=SubTest.hs #-}
```

This would discover `test/Foo/SubTest.hs` and generate
`import qualified Foo.SubTest`.

## Comparison with hspec-discover

| Feature | hspec-discover | hspec-discover-discover |
|---|---|---|
| Discovery | Recursive `*Spec.hs` | Immediate subdirs with configurable file (default `Spec.hs`) + co-located `*Spec.hs` |
| Naming | Any file ending in `Spec.hs` | Configurable file in subdirs, or `*Spec.hs` in same directory |
| Grouping | Flat list of specs | One `describe` per subdirectory or local spec |

Truly, these tools are meant to be used in conjunction with each other.
`hspec-discover-discover` is primarily useful when `hspec-discover`'s single generated `Spec.hs` module becomes too large to compile quickly.
This tool was developed when I noticed that our `Spec.hs` module was taking 2:36 to compile.
Splitting things up into `test/Spec.hs` with this tool (2s compile time) and a myriad of `test/*/TestGroup.hs` files (can compile in parallel much earlier in the build graph) dropped our overall CI build time from 8:00 to 6:30.

## License

BSD-3-Clause
