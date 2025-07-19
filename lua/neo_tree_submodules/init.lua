local renderer = require("neo-tree.ui.renderer")
local events = require("neo-tree.events")
local manager = require("neo-tree.sources.manager")
local file_items = require("neo-tree.sources.common.file-items")

local my_git = require("neo_tree_submodules.git")
local git = require("neo-tree.git")

---Convert a list of paths to unique basenames/basename-folder suffixes
---@param paths string[] The list of paths to get unique names for
---@return string[] # A list of unique names, in the same order as the input list
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

---Draws the menu
local function draw(state)
    if state.loading then
        return
    end
    state.loading = true
    state.default_expanded_nodes = {}

    local git_root = my_git.find_git_root()

    local repos = my_git.list_submodules(git_root)
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

    for _, data in pairs(repo_data) do
        data.root = file_items.create_item(data.context, data.path, "directory")
        data.root.id = "neo_tree_submodules:root:" .. data.root.id
        data.root.name = data.name
        data.root.loaded = true
        data.root.search_pattern = state.search_pattern
        data.context.folders[data.root.id] = data.root

        local status_lookup, _ = git.status(state.git_base, true, data.path)

        for path, status in pairs(status_lookup) do
            local success, item = pcall(file_items.create_item, data.context, path, "file")
            item.status = status
            if success then
                item.extra = {
                    git_status = status,
                }
            end
        end

        for id, _ in pairs(data.context.folders) do
            table.insert(state.default_expanded_nodes, id)
        end

        data.status = status_lookup
        file_items.advanced_sort(data.root.children, state)
    end

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


local M = {
    name = "neo_tree_submodules",
    display_name = " Submodules "
}

M.navigate = function(state, path, path_to_reveal, callback, async)
    state.path = path or state.path
    state.dirty = false
    if path_to_reveal then
        renderer.position.set(state, path_to_reveal)
    end

    draw(state)

    if type(callback) == "function" then
        vim.schedule(callback)
    end
end

M.refresh = function()
  manager.refresh(M.name)
end

M.setup = function(config, global_config)
    manager.subscribe(M.name, {
        event = events.GIT_EVENT,
        handler = M.refresh,
    })
end

return M
