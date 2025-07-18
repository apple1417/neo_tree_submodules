local renderer = require("neo-tree.ui.renderer")
local file_items = require("neo-tree.sources.common.file-items")
local log = require("neo-tree.log")
local git = require("neo-tree.git")

local utils = require("neo-tree.utils")


local M = {}

local function list_submodules()
    local ok, git_output = utils.execute_command({ "git", "submodule", "status", "--recursive" })
    if not ok then
        log.trace("GIT SUBMODULE STATUS ERROR ", git_output)
        return {}
    end
    if not git_output then
        return {}
    end
    local submodules_paths = {}
    for _, line in pairs(git_output) do
        local parts = vim.split(line, " ")
        table.insert(submodules_paths, parts[3])
    end
    return submodules_paths
end

---Get a table of all open buffers, along with all parent paths of those buffers.
---The paths are the keys of the table, and all the values are 'true'.
M.get_git_status = function(state)
    if state.loading then
        return
    end
    state.loading = true
    local status_lookup, project_root = git.status(state.git_base, true, state.path)

    local submodules = list_submodules()


    state.path = project_root or state.path or vim.fn.getcwd()
    local context = file_items.create_context()
    context.state = state
    -- Create root folder
    local root = file_items.create_item(context, state.path, "directory")
    root.name = vim.fn.fnamemodify(root.path, ":~")
    root.loaded = true
    root.search_pattern = state.search_pattern
    context.folders[root.path] = root

    for path, status in pairs(status_lookup) do
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
    end

    state.git_status_lookup = status_lookup
    state.default_expanded_nodes = {}
    for id, _ in pairs(context.folders) do
        table.insert(state.default_expanded_nodes, id)
    end
    file_items.advanced_sort(root.children, state)
    renderer.show_nodes({ root }, state)
    state.loading = false
end

return M
