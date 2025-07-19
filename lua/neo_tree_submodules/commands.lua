local cc = require("neo-tree.sources.common.commands")
local utils = require("neo-tree.utils")
local manager = require("neo-tree.sources.manager")
local events = require("neo-tree.events")
local inputs = require("neo-tree.ui.inputs")
local popups = require("neo-tree.ui.popups")

local M = {}

-- overwrite all the common git actions to be submodule specific
-- this is mostly copied from there, just adding extra checks to grab the submodule path

M.git_add_file = function(state)
    local node = assert(state.tree:get_node())
    if node.type == "message" then
        return
    end
    if node.extra == nil or node.extra.submodule == nil then
        popups.alert("neo_tree_submodules", "couldn't find submodule for selected node")
        return
    end

    local cmd = { "git", "-C", node.extra.submodule, "add", node.path }
    vim.fn.system(cmd)
    events.fire_event(events.GIT_EVENT)
end

M.git_add_all = function(state)
    local node = assert(state.tree:get_node())
    if node.extra == nil or node.extra.submodule == nil then
        popups.alert("neo_tree_submodules", "couldn't find submodule for selected node")
        return
    end

    local cmd = { "git", "-C", node.extra.submodule, "add", "-A" }
    vim.fn.system(cmd)
    events.fire_event(events.GIT_EVENT)
end

M.git_commit = function(state, and_push)
    local node = assert(state.tree:get_node())
    if node.extra == nil or node.extra.submodule == nil then
        popups.alert("neo_tree_submodules", "couldn't find submodule for selected node")
        return
    end

    local width = vim.fn.winwidth(0) - 2
    local row = vim.api.nvim_win_get_height(0) - 3
    local popup_options = {
        relative = "win",
        position = {
            row = row,
            col = 0,
        },
        size = width,
    }

    inputs.input("Commit message: ", "", function(msg)
    local cmd = { "git", "-C", node.extra.submodule, "commit", "-m", msg }
    local title = "git commit"
    local result = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 or (#result > 0 and vim.startswith(result[1], "fatal:")) then
        popups.alert("ERROR: git commit", result)
        return
    end
    if and_push then
        title = "git commit && git push"
        cmd = { "git", "-C", node.extra.submodule, "push" }
        local result2 = vim.fn.systemlist(cmd)
        table.insert(result, "")
        for i = 1, #result2 do
            table.insert(result, result2[i])
        end
    end
    events.fire_event(events.GIT_EVENT)
    popups.alert(title, result)
    end, popup_options)
end

M.git_commit_and_push = function(state)
    M.git_commit(state, true)
end

M.git_push = function(state)
    local node = assert(state.tree:get_node())
    if node.extra == nil or node.extra.submodule == nil then
        popups.alert("neo_tree_submodules", "couldn't find submodule for selected node")
        return
    end

    inputs.confirm("Are you sure you want to push your changes?", function(yes)
        if yes then
            local result = vim.fn.systemlist({ "git", "-C", node.extra.submodule, "push" })
            events.fire_event(events.GIT_EVENT)
            popups.alert("git push", result)
        end
    end)
end

M.git_unstage_file = function(state)
    local node = assert(state.tree:get_node())
    if node.type == "message" then
        return
    end
    if node.extra == nil or node.extra.submodule == nil then
        popups.alert("neo_tree_submodules", "couldn't find submodule for selected node")
        return
    end

    local cmd = { "git", "-C", node.extra.submodule, "reset", "--", node.path }
    vim.fn.system(cmd)
    events.fire_event(events.GIT_EVENT)
end

M.git_undo_last_commit = function(state)
    local node = assert(state.tree:get_node())
    if node.extra == nil or node.extra.submodule == nil then
        popups.alert("neo_tree_submodules", "couldn't find submodule for selected node")
        return
    end

    inputs.confirm("Are you sure you want to undo the last commit? (keeps changes)", function(yes)
        if yes then
            local cmd = { "git", "-C", node.extra.submodule, "reset", "--soft", "HEAD~1" }
            local result = vim.fn.systemlist(cmd)
            if vim.v.shell_error ~= 0 then
                popups.alert("ERROR: git reset --soft HEAD~1", result)
                return
            end
            events.fire_event(events.GIT_EVENT)
            popups.alert(
                "git reset --soft HEAD~1",
                { "Last commit undone successfully", "Changes kept in staging area" }
            )
        end
    end)
end

M.git_revert_file = function(state)
    local node = assert(state.tree:get_node())
    if node.type == "message" then
        return
    end
    if node.extra == nil or node.extra.submodule == nil then
        popups.alert("neo_tree_submodules", "couldn't find submodule for selected node")
        return
    end

    local cmd = { "git", "-C", node.extra.submodule, "checkout", "HEAD", "--", node.path }
    local msg = string.format("Are you sure you want to revert %s?", node.name)
    inputs.confirm(msg, function(yes)
        if yes then
            vim.fn.system(cmd)
            events.fire_event(events.GIT_EVENT)
        end
    end)
end

-- then these overrides are all copied from the standard git_status source, just to redirect to our
-- refresh/redraw funcs

local refresh = utils.wrap(manager.refresh, "neo_tree_submodules")
local redraw = utils.wrap(manager.redraw, "neo_tree_submodules")

M.add = function(state)
  cc.add(state, refresh)
end
M.add_directory = function(state)
  cc.add_directory(state, refresh)
end
M.copy_to_clipboard = function(state)
  cc.copy_to_clipboard(state, redraw)
end
M.copy_to_clipboard_visual = function(state, selected_nodes)
  cc.copy_to_clipboard_visual(state, selected_nodes, redraw)
end
M.cut_to_clipboard = function(state)
  cc.cut_to_clipboard(state, redraw)
end
M.cut_to_clipboard_visual = function(state, selected_nodes)
  cc.cut_to_clipboard_visual(state, selected_nodes, redraw)
end
M.copy = function(state)
  cc.copy(state, redraw)
end
M.move = function(state)
  cc.move(state, redraw)
end
M.paste_from_clipboard = function(state)
  cc.paste_from_clipboard(state, refresh)
end
M.delete = function(state)
  cc.delete(state, refresh)
end
M.delete_visual = function(state, selected_nodes)
  cc.delete_visual(state, selected_nodes, refresh)
end
M.refresh = refresh
M.rename = function(state)
  cc.rename(state, refresh)
end

cc._add_common_commands(M)
return M

