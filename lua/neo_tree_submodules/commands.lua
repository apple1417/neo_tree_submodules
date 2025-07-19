local cc = require("neo-tree.sources.common.commands")
local utils = require("neo-tree.utils")
local manager = require("neo-tree.sources.manager")

local M = {}

local refresh = utils.wrap(manager.refresh, "neo_tree_submodules")
local redraw = utils.wrap(manager.redraw, "neo_tree_submodules")

-- these overrides are all copied from the standard git_status source
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

