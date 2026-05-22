return {
	{ "akinsho/toggleterm.nvim", version = "*", config = true },

    vim.keymap.set("n", "<leader>tt", ":ToggleTerm<CR>", {}),
    vim.keymap.set("n", "<leader>tf", ":ToggleTerm direction=float<CR>", {}),

}
