# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

hspec-discover-discover is a Haskell project built with Stack (LTS 24.31). It uses `package.yaml` (hpack) for package configuration, which generates the `.cabal` file.

## Build Commands

```bash
stack build                          # Build the project
stack test                           # Run tests
stack run                            # Run the executable (hspec-discover-discover-exe)
stack build --fast                   # Build without optimizations (faster compile)
stack test --fast                    # Test without optimizations
stack ghci                           # Load library into REPL
```

## Project Structure

- `src/` — Library source (`Lib` module)
- `app/` — Executable entry point (`Main.hs`), depends on the library
- `test/` — Test suite (`Spec.hs`), depends on the library
- `package.yaml` — Package definition (hpack format, source of truth for dependencies and configuration)

## GHC Warnings

The project enables strict warnings including `-Wall`, `-Wcompat`, `-Wincomplete-record-updates`, `-Wincomplete-uni-patterns`, `-Wmissing-export-lists`, and `-Wredundant-constraints`. All modules must have explicit export lists.
