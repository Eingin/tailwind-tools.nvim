local M = {}

local log = require("tailwind-tools.log")
local lsp = require("tailwind-tools.lsp")
local state = require("tailwind-tools.state")
local config = require("tailwind-tools.config")
local conceal = require("tailwind-tools.conceal")
local motions = require("tailwind-tools.motions")
local keymaps = require("tailwind-tools.keymaps")

local function register_usercmd()
  local usercmd = vim.api.nvim_create_user_command

  usercmd("TailwindConcealEnable", conceal.enable, { nargs = 0 })
  usercmd("TailwindConcealDisable", conceal.disable, { nargs = 0 })
  usercmd("TailwindConcealToggle", conceal.toggle, { nargs = 0 })
  usercmd("TailwindSort", lsp.sort_classes, { nargs = 0 })
  usercmd("TailwindSortSelection", lsp.sort_selection, { range = "%" })
  usercmd("TailwindColorEnable", lsp.enable_color, { nargs = 0 })
  usercmd("TailwindColorDisable", lsp.disable_color, { nargs = 0 })
  usercmd("TailwindColorToggle", lsp.toggle_colors, { nargs = 0 })
  usercmd("TailwindNextClass", motions.move_to_next_class, { nargs = 0, range = "%" })
  usercmd("TailwindPrevClass", motions.move_to_prev_class, { nargs = 0, range = "%" })
  usercmd("TailwindSortSync", function() lsp.sort_classes(true) end, { nargs = 0 })
  usercmd("TailwindSortSelectionSync", function() lsp.sort_selection(true) end, { range = "%" })
end

local function register_autocmd()
  local autocmd = vim.api.nvim_create_autocmd

  autocmd("LspAttach", {
    group = state.color_au,
    callback = lsp.on_attach_cb,
  })

  autocmd({ "TextChanged", "TextChangedI" }, {
    group = state.conceal_au,
    callback = conceal.on_text_changed,
  })

  autocmd("BufEnter", {
    group = state.conceal_au,
    callback = conceal.on_buf_enter,
  })

  autocmd("Colorscheme", {
    group = state.color_au,
    callback = function()
      lsp.color_request(nil, 0)
      vim.api.nvim_set_hl(0, "TailwindConceal", config.options.conceal.highlight)
    end,
  })
end

---@param options TailwindTools.Option
M.setup = function(options)
  if vim.fn.has("nvim-0.11") ~= 1 then
    log.error("tailwind-tools.nvim requires Neovim 0.11 or higher")
    return
  end

  options = options or {}

  vim.validate("server", options.server, "table", true)
  vim.validate("document_color", options.document_color, "table", true)
  vim.validate("conceal", options.conceal, "table", true)
  vim.validate("extension", options.extension, "table", true)
  vim.validate("keymaps", options.keymaps, "table", true)

  if options.document_color then
    vim.validate("document_color.kind", options.document_color.kind, "string", true)
    vim.validate("document_color.debounce", options.document_color.debounce, "number", true)
    vim.validate("document_color.inline_symbol", options.document_color.inline_symbol, "string", true)
  end

  if options.server then
    vim.validate("server.override", options.server.override, "boolean", true)
    vim.validate("server.on_attach", options.server.on_attach, "function", true)
    vim.validate("server.root_markers", options.server.root_markers, "table", true)
    vim.validate("server.settings", options.server.settings, "table", true)
  end

  config.options = vim.tbl_deep_extend("keep", options, config.options)

  state.conceal.enabled = config.options.conceal.enabled
  state.color.enabled = config.options.document_color.enabled

  vim.g.tailwind_tools = true

  vim.api.nvim_set_hl(0, "TailwindConceal", config.options.conceal.highlight)

  local server_opts = config.options.server
  local has_telescope, telescope = pcall(require, "telescope")

  if has_telescope then telescope.load_extension("tailwind") end
  if server_opts.override then lsp.setup(server_opts) end
  if config.options.keymaps.smart_increment.enabled then keymaps.set_smart_increment() end

  register_usercmd()
  register_autocmd()
end

return M
