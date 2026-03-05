return {
  color_ns = vim.api.nvim_create_namespace("tailwind_colors"),
  color_au = vim.api.nvim_create_augroup("tailwind_colors", {}),
  conceal_ns = vim.api.nvim_create_namespace("tailwind_conceal"),
  conceal_au = vim.api.nvim_create_augroup("tailwind_conceal", {}),
  conceal = {
    enabled = false,
    active_buffers = {},
  },
  color = {
    enabled = false,
    active_buffers = {},
  },
  smart_increment = {
    active = false,
  },
}
