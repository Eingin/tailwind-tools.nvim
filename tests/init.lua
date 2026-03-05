-- minimal init.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)
vim.o.swapfile = false

require("lazy").setup({
  { "nvim-lua/plenary.nvim" },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "html", "css", "javascript", "typescript", "tsx", "templ" },
        sync_install = true,
        highlight = { enable = true },
      })
    end,
  },
  { "nvim-telescope/telescope.nvim" },
  {
    dir = "./",
    priority = 1000,
    config = function() require("tailwind-tools").setup({}) end,
  },
}, {
  defaults = { lazy = false },
})

