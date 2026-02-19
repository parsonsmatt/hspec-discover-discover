# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

hspec-discover-discover is a GHC preprocessor for hspec that discovers test modules in immediate subdirectories. Built with Stack (LTS 24.31), uses `package.yaml` (hpack) for package configuration.

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
- `package.yaml` — Package definition (hpack format, source of truth for dependencies and configuration)
- `fourmolu.yaml` — Formatter configuration

## Formatting

Run `make format` (or `fourmolu -i **/*.hs`) before committing. The project uses fourmolu with 4-space indentation, leading commas, and leading import/export style. CI checks formatting via Restyled.

## GHC Warnings

The project enables strict warnings including `-Wall`, `-Wcompat`, `-Wincomplete-record-updates`, `-Wincomplete-uni-patterns`, `-Wmissing-export-lists`, and `-Wredundant-constraints`. All modules must have explicit export lists.
