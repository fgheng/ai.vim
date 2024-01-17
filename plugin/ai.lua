vim.api.nvim_create_user_command("AI", function (args)
    require("_ai/commands").ai(args)
end, {
    range = true,
    nargs = "*",
})

if not vim.g.ai_no_mappings then
    vim.api.nvim_set_keymap("n", "<leader>a", ":AI ", { noremap = true })
    vim.api.nvim_set_keymap("v", "<leader>a", ":AI ", { noremap = true })
    vim.api.nvim_set_keymap("i", "<leader>a", "<Esc>:AI<CR>a", { noremap = true })
end
