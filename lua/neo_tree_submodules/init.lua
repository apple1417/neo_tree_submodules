local utils = require("neo-tree.utils")
local renderer = require("neo-tree.ui.renderer")
local events = require("neo-tree.events")
local manager = require("neo-tree.sources.manager")

local submodules = require("neo_tree_submodules.submodules")

local M = {
    name = "neo_tree_submodules",
    display_name = " Submodules ",
    default_config = require("neo_tree_submodules.config"),
}

M.navigate = function(state, path, path_to_reveal, callback)
    -- same rough logic as the standard git_status source, just swapping to our custom function
    state.path = path or state.path
    state.dirty = false
    if path_to_reveal then
        renderer.position.set(state, path_to_reveal)
    end

    submodules.draw(state)

    if type(callback) == "function" then
        vim.schedule(callback)
    end
end

M.refresh = function()
  manager.refresh(M.name)
end

M.setup = function(config, global_config)
    -- all the events are copied from the standard git_status source
    if config.before_render then
        manager.subscribe(M.name, {
            event = events.BEFORE_RENDER,
            handler = function(state)
                local this_state = manager.get_state(M.name)
                if state == this_state then
                    config.before_render(this_state)
                end
            end,
        })
    end

    if global_config.enable_refresh_on_write then
        manager.subscribe(M.name, {
            event = events.VIM_BUFFER_CHANGED,
            handler = function(args)
                if utils.is_real_file(args.afile) then
                    M.refresh()
                end
            end,
        })
    end

    if config.bind_to_cwd then
        manager.subscribe(M.name, {
            event = events.VIM_DIR_CHANGED,
            handler = M.refresh,
        })
    end

    if global_config.enable_diagnostics then
        manager.subscribe(M.name, {
            event = events.STATE_CREATED,
            handler = function(state)
                state.diagnostics_lookup = utils.get_diagnostic_counts()
            end,
        })
        manager.subscribe(M.name, {
            event = events.VIM_DIAGNOSTIC_CHANGED,
            handler = utils.wrap(manager.diagnostics_changed, M.name),
        })
    end

    if global_config.enable_modified_markers then
        manager.subscribe(M.name, {
            event = events.VIM_BUFFER_MODIFIED_SET,
            handler = utils.wrap(manager.opened_buffers_changed, M.name),
        })
    end

    manager.subscribe(M.name, {
        event = events.GIT_EVENT,
        handler = M.refresh,
    })
end

return M
