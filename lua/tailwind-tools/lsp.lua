local M = {}

local log = require("tailwind-tools.log")
local utils = require("tailwind-tools.utils")
local state = require("tailwind-tools.state")
local config = require("tailwind-tools.config")
local classes = require("tailwind-tools.classes")
local filetypes = require("tailwind-tools.filetypes")

local default_root_markers = {
  "tailwind.config.js",
  "tailwind.config.cjs",
  "tailwind.config.mjs",
  "tailwind.config.ts",
  "assets/tailwind.config.js",
  "assets/tailwind.config.cjs",
  "assets/tailwind.config.mjs",
  "assets/tailwind.config.ts",
  "theme/static_src/tailwind.config.js",
  "theme/static_src/tailwind.config.cjs",
  "theme/static_src/tailwind.config.mjs",
  "theme/static_src/tailwind.config.ts",
  "app/assets/stylesheets/application.tailwind.css",
  "app/assets/tailwind/application.css",
  "package.json",
}

local color_events = {
  "BufEnter",
  "TextChanged",
  "TextChangedI",
  "CursorMoved",
  "CursorMovedI",
}

---@return vim.lsp.Client?
local function get_tailwindcss()
  local clients = vim.lsp.get_clients({ name = "tailwindcss" })
  return clients[1]
end

---@param bufnr number
---@param color lsp.ColorInformation
local function set_extmark(bufnr, color)
  local r = math.floor(color.color.red * 255)
  local g = math.floor(color.color.green * 255)
  local b = math.floor(color.color.blue * 255)
  local hl_kind = config.options.document_color.kind
  local hl_group = utils.set_hl_from(r, g, b, hl_kind)
  local namespace = state.color_ns
  local start_row = color.range.start.line
  local start_col = color.range.start.character
  local opts = {}

  if hl_kind == "inline" then
    opts.virt_text = { { config.options.document_color.inline_symbol, hl_group } }
    opts.virt_text_pos = "inline"
  else
    opts.hl_group = hl_group
    opts.end_row = color.range["end"].line
    opts.end_col = color.range["end"].character
    opts.priority = 1000
  end

  vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, start_col, opts)
  state.color.active_buffers[bufnr] = true
end

local debounce_timer = vim.uv.new_timer()

---@param bufnr number
local function debounced_color_request(client, bufnr)
  debounce_timer:stop()
  debounce_timer:start(config.options.document_color.debounce, 0, vim.schedule_wrap(function()
    M.color_request(client, bufnr)
  end))
end

---@param ranges { [integer]: number, delimiter?: { raw: string, pattern: string } }[]
---@param bufnr number
---@param sync boolean
local function sort_classes(ranges, bufnr, sync)
  local client = get_tailwindcss()

  if not client then return log.error("tailwind-language-server is not running") end
  if #ranges == 0 then return end

  local class_text = {}

  for _, range in ipairs(ranges) do
    local start_row, start_col, end_row, end_col = unpack(range)
    local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
    text = table.concat(text, "\n")
    if range.delimiter then text = string.gsub(text, range.delimiter.pattern, " ") end
    class_text[#class_text + 1] = text
  end

  local params = vim.tbl_extend("error", vim.lsp.util.make_text_document_params(bufnr), {
    classLists = class_text,
  })

  local handler = function(err, result, _, _)
    if err then return log.error(err.message) end
    if result.error then return log.error(result.error) end
    if not result or not vim.api.nvim_buf_is_valid(bufnr) then return end

    for i, edit in ipairs(result.classLists) do
      if ranges[i].delimiter then
        edit = table.concat(vim.split(edit, "%s+"), ranges[i].delimiter.raw)
      end

      local lines = vim.split(edit, "\n")
      local s_row, s_col, e_row, e_col = unpack(ranges[i])

      -- Dismiss useless error messages when undoing in nightly
      pcall(function() vim.api.nvim_buf_set_text(bufnr, s_row, s_col, e_row, e_col, lines) end)
    end
  end

  if sync then
    local response = client.request_sync("@/tailwindCSS/sortSelection", params, 2000, bufnr)

    if response then
      handler(response.err, response.result)
    else
      log.error("LSP request timed out")
    end
  else
    client.request("@/tailwindCSS/sortSelection", params, handler, bufnr)
  end
end
---@param _ lsp.ResponseError?
---@param params { message: string }
local function handle_warn(_, params)
  vim.notify(params.message, vim.log.levels.WARN, { title = "Tailwind CSS" })
end

---Clears all color extmarks and re-requests colors for the current buffer.
local function handle_clear_colors()
  for bufnr, _ in pairs(state.color.active_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, state.color_ns, 0, -1)
    end
  end

  if state.color.enabled then
    local client = get_tailwindcss()
    if client then M.color_request(client, vim.api.nvim_get_current_buf()) end
  end
end

---Fires initial color requests for all visible windows once the project is ready.
local function handle_project_initialized()
  state.project.initialized = true

  if not state.color.enabled then return end

  local client = get_tailwindcss()
  if not client then return end

  local seen = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    if not seen[bufnr] and vim.api.nvim_buf_is_loaded(bufnr) then
      seen[bufnr] = true
      M.color_request(client, bufnr)
    end
  end
end

local function handle_project_reset()
  state.project.initialized = false
  handle_clear_colors()
end

---@param server_config TailwindTools.ServerOption
M.setup = function(server_config)
  local settings = { tailwindCSS = {} }
  settings.tailwindCSS = vim.tbl_get(server_config, "settings", "tailwindCSS") or {}
  settings.tailwindCSS =
    vim.tbl_deep_extend("keep", settings.tailwindCSS, server_config.settings or {})
  settings.tailwindCSS.includeLanguages = vim.tbl_extend(
    "keep",
    server_config.settings and server_config.settings.includeLanguages or {},
    filetypes.get_server_map()
  )

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.colorProvider = { dynamicRegistration = true }

  vim.lsp.config["tailwindcss"] = {
    cmd = { "tailwindcss-language-server", "--stdio" },
    filetypes = filetypes.get_all(),
    root_markers = server_config.root_markers or default_root_markers,
    settings = settings,
    on_attach = M.make_on_attach(server_config.on_attach),
    capabilities = capabilities,
    handlers = {
      ["@/tailwindCSS/clearColors"] = handle_clear_colors,
      ["@/tailwindCSS/warn"] = handle_warn,
      ["@/tailwindCSS/projectInitialized"] = handle_project_initialized,
      ["@/tailwindCSS/projectReset"] = handle_project_reset,
      ["@/tailwindCSS/projectsDestroyed"] = handle_project_reset,
    },
  }

  vim.lsp.enable("tailwindcss")
end

---@type fun(user_on_attach: function | nil)
---@return function(client: vim.lsp.Client, bufnr: integer)
M.make_on_attach = function(user_on_attach)
  if type(user_on_attach) == "function" then
    return function(client, bufnr)
      user_on_attach(client, bufnr)
      M.on_attach(client, bufnr)
    end
  else
    return M.on_attach
  end
end

---@param args vim.api.keyset.create_autocmd.callback_args
M.on_attach_cb = function(args)
  local client = get_tailwindcss()
  if not client then return end
  M.on_attach(client, args.buf)
end

---@param client vim.lsp.Client
---@param bufnr integer
M.on_attach = function(client, bufnr)
  vim.api.nvim_create_autocmd(color_events, {
    group = state.color_au,
    buffer = bufnr,
    callback = function(a)
      if not state.color.enabled then return end
      if a.event == "TextChangedI" then
        debounced_color_request(client, bufnr)
      elseif vim.startswith(a.event, "Cursor") == state.conceal.enabled then
        M.color_request(client, bufnr)
      end
    end,
  })

  if state.color.enabled and state.project.initialized then
    M.color_request(client, bufnr)
  end
end

---@param client vim.lsp.Client | nil
---@param bufnr number
M.color_request = function(client, bufnr)
  client = client or get_tailwindcss()
  if not client then return end

  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }

  client.request("textDocument/documentColor", params, function(err, result, _, _)
    if err then return log.error(err.message) end
    if not result or not vim.api.nvim_buf_is_valid(bufnr) then return end

    ---@type lsp.ColorInformation[]
    local colors = result
    vim.api.nvim_buf_clear_namespace(bufnr, state.color_ns, 0, -1)

    for _, color in ipairs(colors) do
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- Starts at 1
      local cursor_aligned = (state.conceal.enabled and cursor_line == color.range.start.line)

      if not state.conceal.enabled or cursor_aligned then
        pcall(function() set_extmark(bufnr, color) end)
      end
    end
  end, bufnr)
end

M.enable_color = function()
  local client = get_tailwindcss()
  if client then
    M.color_request(client, 0)
    state.color.enabled = true
  end
end

M.disable_color = function()
  for bufnr, _ in pairs(state.color.active_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, state.color_ns, 0, -1)
    end
  end

  state.color.active_buffers = {}
  state.color.enabled = false
end

M.toggle_colors = function()
  if state.color.enabled then
    M.disable_color()
  else
    M.enable_color()
  end
end

---@param sync boolean
M.sort_selection = function(sync)
  local bufnr = vim.api.nvim_get_current_buf()
  local s_row, s_col, e_row, e_col = utils.get_visual_range()
  local class_ranges = { { s_row, s_col, e_row, e_col } }

  sort_classes(class_ranges, bufnr, sync)
end

---@param sync boolean
M.sort_classes = function(sync)
  local bufnr = vim.api.nvim_get_current_buf()
  local class_ranges = classes.get_ranges(bufnr, { sortable = true })

  sort_classes(class_ranges, bufnr, sync)
end

return M
