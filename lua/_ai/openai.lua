local M = {}

local config = require("_ai/config")

---@param cmd string
---@param args string[]
---@param on_stdout_chunk fun(chunk: string): nil
---@param on_complete fun(err: string?, output: string?): nil
local function exec (cmd, args, on_stdout_chunk, on_complete)
    local stdout = vim.loop.new_pipe()
    local function on_stdout_read (_, chunk)
        if chunk then
            vim.schedule(function ()
                on_stdout_chunk(chunk)
            end)
        end
    end

    local stderr = vim.loop.new_pipe()
    local stderr_chunks = {}
    local function on_stderr_read (_, chunk)
        if chunk then
            table.insert(stderr_chunks, chunk)
        end
    end

    local handle

    handle, error = vim.loop.spawn(cmd, {
        args = args,
        stdio = {nil, stdout, stderr},
    }, function (code)
        stdout:close()
        stderr:close()
        handle:close()

        vim.schedule(function ()
            if code ~= 0 then
                on_complete(vim.trim(table.concat(stderr_chunks, "")))
            else
                on_complete()
            end
        end)
    end)

    if not handle then
        on_complete(cmd .. " could not be started: " .. error)
    else
        stdout:read_start(on_stdout_read)
        stderr:read_start(on_stderr_read)
    end
end

local function request (endpoint, body, on_data, on_complete)
    local api_key = os.getenv("OPENAI_API_KEY")
    local proxy_url = os.getenv("OPENAI_PROXY")
    if proxy_url == nil then
        proxy_url = "https://api.openai.com/v1"
    end
    if not api_key then
        on_complete("$OPENAI_API_KEY environment variable must be set")
        return
    end

    local curl_args = {
        "--silent", "--show-error", "--no-buffer",
        "--max-time", config.timeout,
        "-L", proxy_url .. "/" .. endpoint,
        "-H", "Authorization: Bearer " .. api_key,
        "-X", "POST", "-H", "Content-Type: application/json",
        "-d", vim.json.encode(body),
    }

    local buffered_chunks = ""
    local function on_stdout_chunk (chunk)
        buffered_chunks = buffered_chunks .. chunk

        -- Extract complete JSON objects from the buffered_chunks
        local json_start, json_end = buffered_chunks:find("}\n")
        while json_start do
            local json_str = buffered_chunks:sub(1, json_end)
            buffered_chunks = buffered_chunks:sub(json_end + 1)

            -- Remove the "data: " prefix
            json_str = json_str:gsub("data: ", "")

            local json = vim.json.decode(json_str)
            if json.error then
                on_complete(json.error.message)
            else
                on_data(json)
            end

            json_start, json_end = buffered_chunks:find("}\n")
        end
    end

    exec("curl", curl_args, on_stdout_chunk, on_complete)
end

---@param body table
---@param on_data fun(data: unknown): nil
---@param on_complete fun(err: string?): nil
function M.completions (body, on_data, on_complete)
    local prompt = body.prompt
    local request_body = {
        model = config.completions_model,
        temperature = config.temperature,
        stream = true,
        messages = {
          {
            role = "user",
            content = prompt
          }
        }
    }
    request("completions", request_body, on_data, on_complete)
end

---@param body table
---@param on_data fun(data: unknown): nil
---@param on_complete fun(err: string?): nil
function M.edits (body, on_data, on_complete)
    local prompt = body.instruction
    local _input = body.input
    local request_body = {
        model = config.completions_model,
        temperature = config.temperature,
        stream = true,
        messages = {
          {
            role = "user",
            content = prompt .. " " .. _input
          }
        }
    }
    request("completions", request_body, on_data, on_complete)
end

return M
