# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

hspec-discover-discover is a GHC preprocessor for hspec that discovers test modules in immediate subdirectories (configurable filename, default `Spec.hs`) and co-located `*Spec.hs` files. The subdirectory filename can be changed via `--subdir-file`. Built with Stack (LTS 24.31), uses `package.yaml` (hpack) for package configuration.

## Build Commands

```bash
stack build                          # Build the project
stack test                           # Run tests
stack build --fast                   # Build without optimizations (faster compile)
stack test --fast                    # Test without optimizations
stack ghci                           # Load library into REPL
make format                         # Format all Haskell files with fourmolu
```

## Project Structure

- `src/Hspec/Discover/Discover.hs` — Core library module
- `app/Main.hs` — Executable entry point, calls `Hspec.Discover.Discover.run`
- `test/` — Test suite, dogfoods `hspec-discover-discover` as its own preprocessor
  - `test/Spec.hs` — Preprocessor entry point
  - `test/ParseArgs/Spec.hs` — Argument parsing tests
  - `test/Discover/Spec.hs` — Directory discovery tests
  - `test/Generate/Spec.hs` — Code generation tests
  - `test/Pragmas/Spec.hs` — Pragma extraction tests
  - `test/Validate/Spec.hs` — Validation tests
- `docs/` — Project documentation
  - `docs/ai-haskell-guide.md` — Haskell style guide for AI agents
  - `docs/refactoring-notes.md` — Refactoring history and rationale
- `package.yaml` — Package definition (hpack format, source of truth for dependencies and configuration)
- `fourmolu.yaml` — Formatter configuration

## Formatting

Run `make format` (or `fourmolu -i **/*.hs`) before committing. The project uses fourmolu with 4-space indentation, leading commas, and leading import/export style. CI checks formatting via Restyled.

## Haskell Style Guide

For detailed patterns and anti-patterns (strict data, monoid-based accumulation, concurrency, avoiding allocations, naming conventions, etc.), see [`docs/ai-haskell-guide.md`](docs/ai-haskell-guide.md). The checklist at the end of that document should be consulted when writing or reviewing code.

## Code Style

- **Imports**: Use qualified imports for utility modules (e.g. `qualified Data.Text.Lazy.Builder as TLB`, `qualified Options.Applicative as Opts`). Import types unqualified (e.g. `import Data.Text.Lazy (Text)`).
- **Text**: Use `Data.Text.Lazy.Builder` for string construction, `Data.Text.Lazy.IO` for file I/O. Avoid `String` for output; `String`/`FilePath` is fine at the filesystem boundary.
- **Warnings**: The project enables strict warnings including `-Wall`, `-Wcompat`, `-Wincomplete-record-updates`, `-Wincomplete-uni-patterns`, `-Wmissing-export-lists`, and `-Wredundant-constraints`. All modules must have explicit export lists. The build must be warning-free.

## Adding Tests

The test suite dogfoods `hspec-discover-discover` as its own preprocessor. To add a new test group, either create a `test/<Name>/Spec.hs` module or a `test/<Name>Spec.hs` module that exports `spec :: Spec` — it will be automatically discovered.
