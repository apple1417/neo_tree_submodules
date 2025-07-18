local renderer = require("neo-tree.ui.renderer")
local events = require("neo-tree.events")
local manager = require("neo-tree.sources.manager")

local git = require("neo_tree_submodules.git")

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
    git.get_git_status(state)

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
