return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require('codex').status()
    require("lualine").setup({
      options = {
        theme = "auto",
      },
    })
  end,
}
