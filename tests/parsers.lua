local parsers = {
  "html",
  "css",
  "tsx",
  "astro",
  "php",
  "twig",
  "svelte",
  "vue",
  "clojure",
  "htmldjango",
  "heex",
  "elixir",
  "javascript",
  "typescript",
  "templ",
}

-- Use bang (!) to force reinstall without prompt
for _, parser in ipairs(parsers) do
  vim.cmd("TSInstallSync! " .. parser)
end
vim.cmd.quit()
