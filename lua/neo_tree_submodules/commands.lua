local cc = require("neo-tree.sources.common.commands")
local manager = require("neo-tree.sources.manager")

local M = {}

M.refresh = function(state)
    manager.refresh("neo_tree_submodules", state)
end

cc._add_common_commands(M)
return M
