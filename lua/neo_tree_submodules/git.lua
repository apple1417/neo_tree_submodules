local M = {}

---Converts a possibly octal encoded file path to utf8
---@param text string
---@return string
local function octal_to_utf8(text)
    local success, converted = pcall(string.gsub, text, "\\([0-7][0-7][0-7])", function(octal)
        return string.char(tonumber(octal, 8))
    end)
    if success then
        return converted
    else
        return text
    end
end

---Finds the root dir of the git repo the cwd is under
---@return string? # The root dir, or nil if not found
M.find_git_root = function()
    local ret = vim.system(
        { "git", "rev-parse", "--show-toplevel" },
        { text=true }
    ):wait()
    if ret.code ~= 0 or ret.stdout == nil or #ret.stdout == 0 then
        -- error
        return nil
    end
    return vim.fs.abspath(octal_to_utf8(vim.trim(ret.stdout)))
end

---Recursively gets all submodules under the given git root
---@param git_root string? The root git directory to search under
---@return string[] # Paths to each submodule's root
M.list_submodules = function(git_root)
    git_root = git_root or "."

    local ret = vim.system(
        { "git", "submodule", "status", "--recursive" },
        { cwd=git_root, text=true }
    ):wait()

    if ret.code ~= 0 then
        -- error
        return {}
    end
    if ret.stdout == nil or #ret.stdout == 0 then
        -- no submodules
        return {}
    end

    local submodules_paths = {}
    for _, line in pairs(vim.split(ret.stdout, "\n")) do
        local match = line:match("^.[0-9a-fA-F]+ (.+) %(..-%)$")
        if match ~= nil then
            local path = vim.fs.abspath(vim.fs.joinpath(git_root, octal_to_utf8(match)))
            table.insert(submodules_paths, path)
        end
    end
    return submodules_paths
end

return M
