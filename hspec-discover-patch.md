# hspec-discover patch: add --module-prefix flag

## Problem

When `hspec-discover` is used as a preprocessor in a subdirectory (not the test root), it generates unqualified module imports that don't resolve.

For example, with this structure:

```
test/
  Spec.hs                    -- uses hspec-discover-discover
  Generate/
    Spec.hs                  -- uses hspec-discover
    GenerateSpec.hs           -- module Generate.GenerateSpec
```

`hspec-discover` generates:

```haskell
import qualified GenerateSpec
```

But GHC needs:

```haskell
import qualified Generate.GenerateSpec
```

Because the source root is `test/`, not `test/Generate/`.

## Solution

Add a `--module-prefix` CLI flag. When provided, it is prepended to all discovered module names in the generated imports and `describe` calls.

### Usage

```
{-# OPTIONS_GHC -F -pgmF hspec-discover -optF --module-name=Generate.Spec -optF --module-prefix=Generate #-}
```

### Expected behavior

Without `--module-prefix` (current behavior):

```haskell
module Generate.Spec where
import qualified GenerateSpec
spec = describe "GenerateSpec" GenerateSpec.spec
```

With `--module-prefix=Generate`:

```haskell
module Generate.Spec where
import qualified Generate.GenerateSpec
spec = describe "GenerateSpec" Generate.GenerateSpec.spec
```

Note: the `describe` label stays as `"GenerateSpec"` (without prefix) since it's just a display name. Only the qualified import and qualified usage get the prefix.

## Implementation

1. Add `--module-prefix` to the CLI argument parser (alongside existing `--module-name`). Default to empty/no prefix.
2. When generating imports and spec references, prepend `<prefix>.` to each discovered module name if a prefix is provided.
3. That's it — the discovery logic itself doesn't change, only the generated output.

## Verification

```bash
hspec-discover SRC SRC /dev/stdout --module-name=Generate.Spec --module-prefix=Generate
```

Should produce imports like `import qualified Generate.GenerateSpec` instead of `import qualified GenerateSpec`.
