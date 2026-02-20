# AI Agent Guide: Writing High-Quality Haskell

This document captures patterns and anti-patterns for AI agents working on
Haskell codebases. These are lessons learned from real refactoring sessions
and represent the kind of improvements a skilled Haskell developer would
expect.

## Recursion

**Don't write manual recursion when a combinator exists.**

Manual `go` loops with accumulator patterns are a code smell. Ask yourself:

- Am I folding? Use `foldMap`, `foldl'`, or `foldlM`.
- Am I mapping with effects? Use `mapM` or `traverse`.
- Am I mapping independently with IO? Use `mapConcurrently` from `async`.
- Am I taking a prefix? Use `takeWhile`.
- Am I filtering? Use `filter`.

Compose these combinators in pipelines. If a pipeline step has a compound
predicate (e.g., `\x -> isPragma x || isBlank x`), consider whether
reordering the pipeline eliminates the disjunction. For example, filtering
out blank lines *before* `takeWhile isPragma` means `takeWhile` only needs
a single-concern predicate.

## Data types and Monoid

**If you're accumulating into a record, make the record a Monoid.**

Instead of:

```haskell
go acc [] = pure acc
go acc (x:xs) = do
    ...
    go acc{field = newVal : field acc} xs
```

Write:

```haskell
instance Semigroup Foo where
    a <> b = Foo { field = field a <> field b, ... }
instance Monoid Foo where
    mempty = Foo { field = mempty, ... }

-- then:
mconcat <$> mapConcurrently classify entries
```

This also enables concurrency for free (see below).

## Strict data

**Always use `{-# LANGUAGE StrictData #-}` unless you have a reason not to.**

Lazy fields in data types cause thunk accumulation, especially during folds.
`StrictData` makes all fields strict by default. You can opt back into
laziness with `~` on individual fields if needed.

This is especially important for:
- Accumulator types used in folds
- Config/parameter records threaded through the program
- Any type used with `Monoid` and `foldMap`

## Thunks in tuples

**The `Monoid` instance for `(a, b)` is lazy. Use a strict pair.**

If you `foldMap` a function returning `(Builder, Builder)`, both components
accumulate thunks. Define a strict pair instead:

```haskell
data Pair = Pair Builder Builder

instance Semigroup Pair where
    Pair a1 b1 <> Pair a2 b2 = Pair (a1 <> a2) (b1 <> b2)

instance Monoid Pair where
    mempty = Pair mempty mempty
```

With `StrictData`, this evaluates both components at every `<>`.

## Builder patterns

**Use `mconcat [...]` instead of long `<>` chains.**

```haskell
-- Prefer this:
mconcat
    [ line "foo"
    , line "bar"
    , line "baz"
    ]

-- Over this:
line "foo"
    <> line "bar"
    <> line "baz"
```

`mconcat` on lists can be optimized by GHC's rewrite rules. Long `<>` chains
produce left-nested trees that may not be reassociated.

## Single-pass traversals

**If you traverse a list twice for related data, combine into a product.**

Instead of:

```haskell
imports   = foldMap (\m -> line ("import " <> m)) modules
describes = foldMap (\m -> line ("describe " <> m)) modules
```

Write:

```haskell
Pair imports describes = foldMap entry modules
  where
    entry m = Pair
        (line ("import " <> m))
        (line ("describe " <> m))
```

## Concurrency

**Use `mapConcurrently` when mapping independent IO actions.**

`mapConcurrently` from `async` is a drop-in replacement for `mapM` when the
actions don't depend on each other. Filesystem operations (`doesFileExist`,
`doesDirectoryExist`) are a classic case.

```haskell
-- Sequential:
mconcat <$> mapM classify entries

-- Concurrent:
mconcat <$> mapConcurrently classify entries
```

## Choosing the right type

**Use `Set` when you need uniqueness or ordering.**

If you're collecting items and sorting afterward, use `Set` from the start.
The `Monoid` instance gives you union, and `Set.toAscList` gives sorted
output at the boundary. This eliminates explicit `sort` calls and pairs well
with the `Monoid`-based accumulation pattern.

## Avoiding unnecessary allocations

- **Don't pack to `Text` just to call a `Text` function.** If the equivalent
  function exists for `String`/`[Char]`, use it. Example: `List.isSuffixOf`
  instead of `T.isSuffixOf . T.pack`.
- **Don't convert between lazy and strict `Text` when you can read in the
  right representation.** Use `Data.Text.IO.readFile` for strict,
  `Data.Text.Lazy.IO.readFile` for lazy.
- **Bind repeated expressions.** If `dir </> entry` or `T.pack entry` appears
  more than once, give it a name.

## Naming

- **No single-letter variables in multi-line scopes.** Use `modName` not `m`,
  `entry` not `e`, `subdir` not `s`. Single-letter is fine in tiny helpers
  like `\t -> T.stripSuffix "Spec" t`.
- **Avoid shadows.** If an outer binding is `dir` and a pattern match also
  binds `dir`, rename the outer one to something more specific like `specDir`.
- **Prefer `forM_` over `mapM_` for multi-line lambdas.** Data-first style
  (`forM_ items $ \item -> ...`) reads better than wrapping a long lambda
  in `mapM_`.

## Style checklist

When reviewing or writing Haskell code, check:

- [ ] No manual recursion where a combinator would work
- [ ] Accumulator records have `Monoid` instances
- [ ] `StrictData` is enabled
- [ ] `foldMap` over products uses strict pairs, not tuples
- [ ] `mconcat` instead of long `<>` chains
- [ ] No redundant list traversals
- [ ] Independent IO actions use `mapConcurrently`
- [ ] No `T.pack` / `T.unpack` just to call a function that exists for both types
- [ ] No lazy-to-strict or strict-to-lazy conversions at IO boundaries
- [ ] Repeated subexpressions are bound to names
- [ ] Descriptive variable names in multi-line scopes
- [ ] `fromMaybe` instead of `maybe x id`
- [ ] `DerivingStrategies` with explicit `stock` / `newtype` / `anyclass`
- [ ] Record constructors instead of positional where the type has 3+ fields
