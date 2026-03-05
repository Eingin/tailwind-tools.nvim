> [!IMPORTANT]
> This is a **fork** of [luckasRanarison/tailwind-tools.nvim](https://github.com/luckasRanarison/tailwind-tools.nvim) with additional improvements. See [Fork Changes](#fork-changes) for details.
> This plugin is a community project and is **NOT** officially supported by [Tailwind Labs](https://github.com/tailwindlabs).

# tailwind-tools.nvim

An unofficial [Tailwind CSS](https://github.com/tailwindlabs/tailwindcss) integration and tooling for [Neovim](https://github.com/neovim/neovim) written in Lua and JavaScript, leveraging the built-in LSP client, Treesitter, and the NodeJS plugin host. It is inspired by the official Visual Studio Code [extension](https://github.com/tailwindlabs/tailwindcss-intellisense).

![preview](https://github.com/luckasRanarison/tailwind-tools.nvim/assets/101930730/cb1c0508-8375-474f-9078-2842fb62e0b7)

## Contents
- [Fork Changes](#fork-changes)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Commands](#commands)
- [Utilities](#utilities)
- [Extension](#extension)
- [Related projects](#related-projects)
- [Contributing](#contributing)

## Fork Changes

This fork requires **Neovim 0.11+** and drops the `nvim-lspconfig` dependency in favor of the native `vim.lsp.config` / `vim.lsp.enable` API.

### Neovim 0.11 modernization

- Uses `vim.lsp.config` and `vim.lsp.enable` for LSP server setup (no `nvim-lspconfig` required)
- Replaces `vim.loop` with `vim.uv`, `vim.lsp.get_active_clients` with `vim.lsp.get_clients`
- Uses the new `vim.validate` positional signature
- Replaces `vim.g` state storage with a Lua module to avoid msgpack serialization on hot paths
- Replaces `vim.defer_fn` debounce with a single persistent `vim.uv.new_timer()`

### LSP notification handlers

The [tailwindcss-language-server](https://github.com/tailwindlabs/tailwindcss-intellisense) sends several custom notifications that the original plugin ignores. This fork handles them:

| Notification | What this fork does |
|---|---|
| `@/tailwindCSS/projectInitialized` | Fires the initial color request only once the Tailwind project is actually ready, fixing a race condition where colors would not appear until the first text edit |
| `@/tailwindCSS/projectReset` | Clears project state and color extmarks when the project reloads (e.g., after a config error) |
| `@/tailwindCSS/projectsDestroyed` | Same as `projectReset`; handles full server disposal/restart |
| `@/tailwindCSS/clearColors` | Clears stale color extmarks and re-requests colors when server settings change |
| `@/tailwindCSS/warn` | Displays server warnings (e.g., config load failures) via `vim.notify` instead of silently ignoring them |

### Bug fixes

- Fixed highlight cache guard in `utils.lua` (`nvim_get_hl` returns a dict, not an array — the cache was a no-op)
- Fixed `tresitter` typo in `classes.lua`
- Replaced `pairs()` with `ipairs()` on array tables throughout

## Features

The plugin works with all languages inheriting from html, css and tsx treesitter grammars (php, astro, vue, svelte, [...](./lua/tailwind-tools/filetypes.lua)). Lua patterns can also be used as a fallback.

It currently provides the following features:

- Class color hints
- Class concealing
- Class motions
- Smart increment (increment/decrement tailwindcss units using `<C-a>` and `<C-x>`)
- Class sorting (without [prettier-plugin](https://github.com/tailwindlabs/prettier-plugin-tailwindcss))
- Completion utilities (using [nvim-cmp](https://github.com/hrsh7th/nvim-cmp))
- Class previewer (using [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim))

> [!NOTE]
> Language services like autocompletion, diagnostics and hover are already provided by [tailwindcss-language-server](https://github.com/tailwindlabs/tailwindcss-intellisense/tree/master/packages/tailwindcss-language-server).

## Prerequisites

- Neovim v0.11 or higher
- [tailwindcss-language-server](https://github.com/tailwindlabs/tailwindcss-intellisense/tree/master/packages/tailwindcss-language-server) >= `v0.0.14` (can be installed using [Mason](https://github.com/williamboman/mason.nvim) or npm)
- `html`, `css`, `tsx` and other language Treesitter grammars (using [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter))
- Neovim [node-client](https://www.npmjs.com/package/neovim) (using npm)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- tailwind-tools.lua
return {
  "luckasRanarison/tailwind-tools.nvim",
  name = "tailwind-tools",
  build = ":UpdateRemotePlugins",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-telescope/telescope.nvim", -- optional
  },
  opts = {} -- your configuration
}
```

If you are using other package managers, you need register the remote plugin by running the `:UpdateRemotePlugins` command, then call `setup` to enable the lua plugin:

```lua
require("tailwind-tools").setup({
  -- your configuration
})
```

## Configuration

By default, the plugin automatically configures tailwindcss-language-server using Neovim's native LSP API (`vim.lsp.config`). Make sure you do not set up the server elsewhere.

Here is the default configuration:

```lua
---@type TailwindTools.Option
{
  server = {
    override = true, -- setup the server from the plugin if true
    settings = { -- shortcut for `settings.tailwindCSS`
      -- experimental = {
      --   classRegex = { "tw\\('([^']*)'\\)" }
      -- },
      -- includeLanguages = {
      --   elixir = "phoenix-heex",
      --   heex = "phoenix-heex",
      -- },
    },
    on_attach = function(client, bufnr) end, -- callback executed when the language server gets attached to a buffer
    root_markers = { "tailwind.config.js", "package.json" }, -- files that mark the project root
  },
  document_color = {
    enabled = true, -- can be toggled by commands
    kind = "inline", -- "inline" | "foreground" | "background"
    inline_symbol = "󰝤 ", -- only used in inline mode
    debounce = 200, -- in milliseconds, only applied in insert mode
  },
  conceal = {
    enabled = false, -- can be toggled by commands
    min_length = nil, -- only conceal classes exceeding the provided length
    symbol = "󱏿", -- only a single character is allowed
    highlight = { -- extmark highlight options, see :h 'highlight'
      fg = "#38BDF8",
    },
  },
  keymaps = {
    smart_increment = { -- increment tailwindcss units using <C-a> and <C-x>
      enabled = true,
      units = {  -- see lua/tailwind/units.lua to see all the defaults
        {
          prefix = "border",
          values = { "2", "4", "6", "8" },
        },
        -- ...
      }
    }
  },
  cmp = {
    highlight = "foreground", -- color preview style, "foreground" | "background"
  },
  telescope = {
    utilities = {
      callback = function(name, class) end, -- callback used when selecting an utility class in telescope
    },
  },
  -- see the extension section to learn more
  extension = {
    queries = {}, -- a list of filetypes having custom `class` queries
    patterns = { -- a map of filetypes to Lua pattern lists
      -- rust = { "class=[\"']([^\"']+)[\"']" },
      -- javascript = { "clsx%(([^)]+)%)" },
    },
  },
}
```

## Commands

Available commands:

- `TailwindConcealEnable`: enables conceal for all buffers.
- `TailwindConcealDisable`: disables conceal.
- `TailwindConcealToggle`: toggles conceal.
- `TailwindColorEnable`: enables color hints for all buffers.
- `TailwindColorDisable`: disables color hints.
- `TailwindColorToggle`: toggles color hints.
- `TailwindSort(Sync)`: sorts all classes in the current buffer.
- `TailwindSortSelection(Sync)`: sorts selected classes in visual mode.
- `TailwindNextClass`: moves the cursor to the nearest next class node.
- `TailwindPrevClass`: moves the cursor to the nearest previous class node.

> [!NOTE]
> In normal mode, `TailwindNextClass` and `TailwindPrevClass` can be used with a count to jump through multiple classes at once.

## Utilities

### nvim-cmp

Utility function for highlighting colors in [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) using [lspkind.nvim](https://github.com/onsails/lspkind.nvim):

```lua
-- nvim-cmp.lua
return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "tailwind-tools",
    "onsails/lspkind-nvim",
    -- ...
  },
  opts = function()
    return {
      -- ...
      formatting = {
        format = require("lspkind").cmp_format({
          before = require("tailwind-tools.cmp").lspkind_format
        }),
      },
    }
  end,
},
```

> [!TIP]
> You can extend it by calling the function and get the returned `vim_item`, see the nvim-cmp [wiki](https://github.com/hrsh7th/nvim-cmp/wiki/Menu-Appearance) to learn more.

### telescope.nvim

The plugins registers by default a telescope extension that you can call using `:Telescope tailwind <subcommand>`

Available subcommands:

- `classes`: Lists all the classes in the current file and allows to jump to the selected location.

- `utilities`: Lists all utility classes available in the current project with a custom callback.

## Extension

The plugin already supports many languages, but requests for additional language support and PRs are welcome. You can also extend the language support in your configuration by using Treesitter queries or Lua patterns (or both).

### Treesitter queries

Treesitter queries are recommended because they can precisely capture the class values at the AST level, but they can be harder to write. If you are not familiar with Treesitter queries, check out the documentation from [Neovim](https://neovim.io/doc/user/treesitter.html#treesitter-query) or [Treesitter](https://tree-sitter.github.io/tree-sitter/using-parsers#query-syntax).

You can define custom queries for a filetype by adding the filetype to the `queries` list, like this:

```lua
{
  extension = {
    queries = { "myfiletype" },
  }
}
```

The plugin will search for a `class.scm` file (classexpr) associated with that filetype in your `runtimepath`. You can use your Neovim configuration folder to store queries in the following way:

```
~/.config/nvim
.
├── init.lua
├── lua
│   └── ...
└── queries
    └── myfiletype
        └── class.scm
```

The `class.scm` file should contain a query used to extract the class values for a given filetype. The class value should be captured using `@tailwind`, as shown in the following example:

```scheme
; queries/myfiletype/class.scm
(attribute
  (attribute_name) @_attribute_name
  (#eq? @_attribute_name "class")
  (quoted_attribute_value
    (attribute_value) @tailwind))
```

Note that quantified captures (using `+` or `?`) cannot be captured using `@tailwind`. Instead, you must capture the parent node using `@tailwind.inner`.

```scheme
(arguments
  (_)+) @tailwind.inner
```

You can also define node offsets by using the `#set!` directive and assign the `start` or `end` variables to some offset values (defaults to 0).

```scheme
((postcss_statement
   (at_keyword) @_keyword
   (#eq? @_keyword "@apply")
   (plain_value)+) @tailwind.inner
 (#set! @tailwind.inner "start" 1))
```

### Lua patterns

[Lua patterns](https://www.lua.org/pil/20.2.html) are easier to write, but they have some limitations. Unlike Treesitter queries, Lua patterns cannot capture nested structures, they are limited to basic pattern matching.

You can define custom patterns by attaching a list of patterns to filetypes. Each pattern should have exactly **one** capture group representing the class value, as shown below:

```lua
{
  extension = {
    patterns = {
      javascript = { "clsx%(([^)]+)%)" },
    },
  }
}
```

> [!TIP]
> Lua patterns can be combined with Treesitter queries. You can use both for a single filetype to get the combined results.

## Related projects

Here are some related projects:

- [tailwindcss-intellisense](https://github.com/tailwindlabs/tailwindcss-intellisense) (official vscode extension)
- [tailwind-sorter.nvim](https://github.com/laytan/tailwind-sorter.nvim) (uses external scripts)
- [tailwind-fold](https://github.com/stivoat/tailwind-fold) (vscode extension)
- [tailwind-fold.nvim](https://github.com/razak17/tailwind-fold.nvim)
- [document-color.nvim](https://github.com/mrshmllow/document-color.nvim) (archived)

## Contributing

Read the documentation carefully before submitting any issue.

Feature and pull requests are welcome.
