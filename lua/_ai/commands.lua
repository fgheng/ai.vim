local M = {}

local openai = require("_ai/openai")
local config = require("_ai/config")
local indicator = require("_ai/indicator")

---@param args { args: string, range: integer }
function M.ai (args)
    local prompt = args.args
    local visual_mode = args.range > 0

    local buffer = vim.api.nvim_get_current_buf()

    local start_row, start_col
    local end_row, end_col

    if visual_mode then
        -- Use the visual selection
        local start_pos = vim.api.nvim_buf_get_mark(buffer, "<")
        start_row = start_pos[1] - 1
        start_col = start_pos[2]

        local end_pos = vim.api.nvim_buf_get_mark(buffer, ">")
        end_row = end_pos[1] - 1
        local line = vim.fn.getline(end_pos[1])
        if line == "" then
            end_col = 0
        else
            end_col = vim.fn.byteidx(line, vim.fn.charcol("'>"))
        end

    else
        -- Use the cursor position
        local start_pos = vim.api.nvim_win_get_cursor(0)
        start_row = start_pos[1] - 1
        local line = vim.fn.getline(start_pos[1])
        if line == "" then
            start_col = 0
        else
            start_col = vim.fn.byteidx(line, vim.fn.charcol("."))
        end
        end_row = start_row
        end_col = start_col
    end

    local start_line_length = vim.api.nvim_buf_get_lines(buffer, start_row, start_row+1, true)[1]:len()
    start_col = math.min(start_col, start_line_length)

    local end_line_length = vim.api.nvim_buf_get_lines(buffer, end_row, end_row+1, true)[1]:len()
    end_col = math.min(end_col, end_line_length)

    local indicator_obj = indicator.create(buffer, start_row, start_col, end_row, end_col)
    local accumulated_text = ""

    local function on_data (data)
        if data.choices[1]["delta"] == nil then
            if data.choices[1]["content"] ~= nil then
                accumulated_text = accumulated_text .. data.choices[1].content
            end
        else
            if data.choices[1]["delta"]["content"] ~= nil then
                accumulated_text = accumulated_text .. data.choices[1].delta.content
            end
        end
        indicator.set_preview_text(indicator_obj, accumulated_text)
    end

    local function on_complete (err)
        if err then
            vim.api.nvim_err_writeln("ai.vim: " .. err)
        elseif #accumulated_text > 0 then
            indicator.set_buffer_text(indicator_obj, accumulated_text)
        end
        indicator.finish(indicator_obj)
    end

    local selected_text
    if visual_mode then
        selected_text = table.concat(vim.api.nvim_buf_get_text(buffer, start_row, start_col, end_row, end_col, {}), "\n")
    else
        selected_text = vim.api.nvim_get_current_line()
    end

    local new_prompt
    if prompt == "" then
        new_prompt = selected_text
    else
        new_prompt = prompt .. "\n" .. selected_text
    end

    openai.completions({
        prompt = new_prompt,
    }, on_data, on_complete)
end

return M
