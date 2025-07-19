local renderer = require("neo-tree.ui.renderer")
local file_items = require("neo-tree.sources.common.file-items")

local M = {}


local function find_git_root()
    local ret = vim.system(
        { "git", "rev-parse", "--show-toplevel" },
        { text=true }
    ):wait()
    if ret.code ~= 0 or ret.stdout == nil or #ret.stdout == 0 then
        -- error
        return nil
    end
    return vim.fs.abspath(vim.trim(ret.stdout))
end

local function list_submodules(git_root)
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
            local path = vim.fs.abspath(vim.fs.joinpath(git_root, match))
            table.insert(submodules_paths, path)
        end
    end
    return submodules_paths
end

local function get_unique_path_names(paths)
    local is_windows = vim.fn.has("win32")
    local path_separator = is_windows and "\\" or "/"

    local path_data = vim.iter(paths):map(function(path)
        -- on windows do both path seperators
        if is_windows then path = path:gsub("/", "\\") end

        local parts = vim.iter(vim.split(path, path_separator)):rev():totable()
        return { n = 1, parts=parts }
    end):totable()

    for i = 1, #path_data do
        local path_a = path_data[i]
        for j = i + 1, #path_data do
            local path_b = path_data[j]

            local n = 1
            while
                n <= #path_a.parts and n <= #path_b.parts
                and path_a.parts[n] == path_b.parts[n]
            do
                n = n + 1
                path_a.n = math.max(path_a.n, n)
                path_b.n = math.max(path_b.n, n)
            end
        end
    end

    return vim.iter(path_data):map(function(data)
        local parts = vim.iter(data.parts):slice(1, data.n):rev():totable()
        return vim.fs.joinpath(unpack(parts))
    end):totable()
end

M.get_git_status = function(state)
    if state.loading then
        return
    end
    state.loading = true
    state.default_expanded_nodes = {}

    local git_root = find_git_root()

    local repos = list_submodules(git_root)
    table.insert(repos, 1, git_root)

    local unique_repo_names = get_unique_path_names(repos)

    local repo_data = vim.iter(repos):enumerate():map(function(i, path)
        local context = file_items.create_context()
        context.state = state

        return {
            path = path,
            name = unique_repo_names[i],
            context = context,
            root = nil,
            status = {},
        }
    end):totable()

    for i, data in pairs(repo_data) do
        data.root = file_items.create_item(data.context, data.path, "directory")
        data.root.name = data.name
        data.root.loaded = true
        data.root.search_pattern = state.search_pattern
        data.context.folders[data.root.path] = data.root


        -- get status

        if #data.status == 0 then
            table.insert(data.root.children, {
                id = "neo_tree_submodules:clean:" .. i,
                name = "clean",
                type = "directory",
                children = {},
            })
        else
            -- not clean so auto expand
            table.insert(state.default_expanded_nodes, data.root.id)
        end

        file_items.advanced_sort(data.root.children, state)
    end

    --[[for path, status in pairs(status_lookup) do
        local success, item = pcall(file_items.create_item, context, path, "file")
        item.status = status
        if success then
            item.extra = {
                git_status = status,
            }
        else
            log.error("Error creating item for " .. path .. ": " .. item)
        end
    end

    for _, path in pairs(submodules) do
        local success, item = pcall(file_items.create_item, context, path, "directory")
        if not success then
            log.error("Error creating item for " .. path .. ": " .. item)
        end
    end]]

    state.path = git_root or state.path or vim.fn.getcwd()
    state.repo_data = repo_data

    renderer.show_nodes(
        vim.iter(repo_data):map(function(data)
            return data.root
        end):totable(),
        state
    )

    state.loading = false
end

return M
