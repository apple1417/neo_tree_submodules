local renderer = require("neo-tree.ui.renderer")
local file_items = require("neo-tree.sources.common.file-items")
local git = require("neo-tree.git")
local git_utils = require("neo-tree.git.utils")

local M = {}

---@class SubModuleStatus
---@field status " "|"-"|"+"|"U"|string The submodule's status
---@field path string The submodule's path

---Recursively gets all submodules under the given git root
---@param git_root string? The root git directory to search under
---@return Iter<SubModuleStatus> # Each detected submodule
M.list_submodules = function(git_root)
    git_root = git_root or "."

    local ret = vim.system(
        { "git", "-C", git_root, "submodule", "status", "--recursive" },
        { text=true }
    ):wait()

    if ret.code ~= 0 then
        -- error
        return {}
    end
    if ret.stdout == nil or #ret.stdout == 0 then
        -- no submodules
        return {}
    end

    return vim.iter(vim.split(ret.stdout, "\n")):map(function(line)
        local status, rel_path = line:match("^(.)[0-9a-fA-F]+ (.+) %(..-%)$")
        if status == nil or rel_path == nil then
            return nil
        end

        local full_path = vim.fs.abspath(
            vim.fs.joinpath(git_root, git_utils.octal_to_utf8(rel_path))
        )
        return { status=status, path=full_path }
    end)
end

---Convert a list of paths to unique basenames/basename-folder suffixes
---@param paths string[] The list of paths to get unique names for
---@return string[] # A list of unique names, in the same order as the input list
M.get_unique_path_names = function(paths)
    local is_windows = vim.fn.has("win32")
    local path_separator = is_windows and "\\" or "/"

    local path_data = vim.iter(paths):map(function(path)
        -- on windows do both path seperators
        if is_windows then path = path:gsub("/", "\\") end

        local parts = vim.iter(vim.split(path, path_separator)):rev():totable()
        return { n = 1, parts=parts }
    end):totable()

    -- for each pair of paths
    for i = 1, #path_data do
        local path_a = path_data[i]
        for j = i + 1, #path_data do
            local path_b = path_data[j]

            -- while the final parts are identical (the list is reversed)
            local n = 1
            while
                n <= #path_a.parts and n <= #path_b.parts
                and path_a.parts[n] == path_b.parts[n]
            do
                -- increase the amount of required parts for both paths
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
M.draw = function(state)
    if state.loading then
        return
    end
    state.loading = true
    state.default_expanded_nodes = {}

    local git_root = git.get_repository_root()

    local repos = M.list_submodules(git_root):filter(
        function(repo)
            -- Ignore any uninitalized submodules
            if repo.status == "-" then
                return false
            end
            -- Run the user filter
            if type(state.submodule_filter) == "function" then
                if not state.submodule_filter(repo.path) then
                    return false
                end
            end
            return true
        end
    ):totable()

    -- Add the root to the list, treat as always modified
    table.insert(repos, 1, { status = "+", path=git_root })

    local unique_repo_names = M.get_unique_path_names(
        vim.iter(repos):map(function(f) return f.path end):totable()
    )

    local repo_data = vim.iter(repos):enumerate():map(function(i, data)
        local context = file_items.create_context()
        context.state = state

        return {
            path = data.path,
            submodule_status = data.status,
            name = unique_repo_names[i],
            context = context,
            root = nil,
            status_lookup = {},
        }
    end):totable()

    for _, data in pairs(repo_data) do
        data.root = file_items.create_item(data.context, data.path, "directory")
        data.root.id = "neo_tree_submodules:root:" .. data.root.id
        data.root.name = data.name
        data.root.loaded = true
        data.root.search_pattern = state.search_pattern
        data.root.extra = { submodule = data.path }

        data.context.folders[data.root.id] = data.root

        -- If the submodule is clean already, no need to do a status on it
        if data.submodule_status ~= " " then
            local status_lookup, _ = git.status(state.git_base, true, data.path)

            for path, status in pairs(status_lookup) do
                local success, item = pcall(file_items.create_item, data.context, path, "file")
                item.status = status
                if success then
                    item.extra = {
                        git_status = status,
                        submodule = data.path,
                    }
                end
            end
            data.status_lookup = status_lookup
        end

        for id, _ in pairs(data.context.folders) do
            table.insert(state.default_expanded_nodes, id)
        end
        file_items.advanced_sort(data.root.children, state)
    end

    state.path = git_root or state.path or vim.fn.getcwd()
    state.git_status_lookup = vim.iter(repo_data):map(
        function(data)
            return data.status_lookup
        end):fold({}, function(acc, v)
            return vim.tbl_extend("keep", acc, v)
        end)

    renderer.show_nodes(
        vim.iter(repo_data):map(function(data)
            return data.root
        end):totable(),
        state
    )

    state.loading = false
end

return M
