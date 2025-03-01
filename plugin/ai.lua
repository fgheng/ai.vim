vim.api.nvim_create_user_command("AI", function (args)
    require("_ai/commands").ai(args)
end, {
    range = true,
    nargs = "*",
})

if not vim.g.ai_no_mappings then
    vim.api.nvim_set_keymap("n", "<leader>a", ":AI ", { noremap = true })
    vim.api.nvim_set_keymap("v", "<leader>a", ":AI ", { noremap = true })
    -- vim.keymap.set("v", "<leader>a", function ()
    --     local buffer = vim.api.get_current_buf()
    --     if vim.api.nvim_buf_get_option(buffer, 'buftype') == '' and vim.api.nvim_buf_get_option(buffer, 'modifiable') then
    --         vim.api.nvim_command("AI")
    --     else
    --         return
    --     end
    -- end, { noremap = true })
    vim.api.nvim_set_keymap("i", "<leader>a", "<Esc>:AI<CR>a", { noremap = true })
end
