# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

tailwind-tools.nvim is a Neovim plugin providing Tailwind CSS integration. It leverages the built-in LSP client, Treesitter, and a NodeJS remote plugin host. Written in Lua with a NodeJS component for utility class extraction.

## Build & Development Commands

**Install test project dependencies (required before LSP tests):**
```bash
cd tests/lsp/v3 && npm install && cd ../v4 && npm install
```

**Install treesitter parsers (required before query/motions/conceal tests):**
```bash
nvim --headless -u tests/init.lua -c "luafile tests/parsers.lua"
```

**Run all tests:**
```bash
nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/ {init = 'tests/init.lua'}"
```

**Run a single test directory:**
```bash
nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/queries/ {init = 'tests/init.lua'}"
```

> **Note:** `PlenaryBustedFile` does not pass `init` to child processes, so always use `PlenaryBustedDirectory` even for single files. The `init` key is required so that plenary's child Neovim processes load plugins (without it, `--noplugin` is used and treesitter parsers become undiscoverable).

**Format Lua code:**
```bash
stylua lua/
```

**Lint Lua code:**
```bash
luacheck lua/
```

**Install NodeJS remote plugin dependencies:**
```bash
cd rplugin/node/tailwind-tools && npm install
```

After modifying the NodeJS plugin, run `:UpdateRemotePlugins` in Neovim.

## Architecture

### Lua Plugin (`lua/tailwind-tools/`)

- `init.lua` - Entry point, registers user commands and autocmds, calls `setup()`, requires Neovim 0.11+
- `config.lua` - Default configuration options with type annotations
- `lsp.lua` - Tailwind LSP integration using native `vim.lsp.config` API: color hints, class sorting via `@/tailwindCSS/sortSelection`
- `classes.lua` - Combines Treesitter and Lua pattern providers to find class ranges
- `treesitter.lua` - Extracts class ranges using Treesitter queries from `queries/<lang>/class.scm`
- `patterns.lua` - Fallback class extraction using Lua patterns
- `filetypes.lua` - Maps filetypes to parsers/patterns and generates LSP `includeLanguages` settings
- `conceal.lua` - Hides long class strings with a conceal character
- `motions.lua` - Provides `TailwindNextClass`/`TailwindPrevClass` navigation
- `keymaps.lua` - Smart increment/decrement for Tailwind units (`<C-a>`/`<C-x>`)
- `units.lua` - Defines incrementable Tailwind unit sequences (spacing, sizing, etc.)

### Treesitter Queries (`queries/<lang>/class.scm`)

Each supported language has a `class.scm` query that captures Tailwind class values with `@tailwind` or `@tailwind.inner`. Metadata directives (`#set!`) control offset and sorting behavior.

### NodeJS Remote Plugin (`rplugin/node/tailwind-tools/`)

Provides two RPC functions:
- `TailwindGetUtilities` - Returns all utility classes from project's Tailwind config
- `TailwindExpandUtilities` - Expands class names to CSS using PostCSS/Tailwind

Uses project-local `tailwindcss` from `node_modules` via dynamic require resolution.

### Test Structure (`tests/`)

Uses plenary.nvim's busted-style testing:
- `tests/queries/*_spec.lua` - Test class range extraction for each language
- `tests/lsp/` - LSP integration tests with mock Tailwind server (v3 and v4)
- `tests/motions/`, `tests/conceal/`, `tests/keymaps/` - Feature-specific tests
- `tests/queries/runner.lua` - Shared test harness for query specs

## Code Style

- 100-character line width, 2-space indentation (see `.stylua.toml`)
- Double quotes preferred
- Simple statements collapsed to single lines
