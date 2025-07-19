local git_status = require("neo-tree.sources.git_status.components")
local hl = require("neo-tree.ui.highlights")

local M = {}

-- we can mostly use the standard git status's components, just need to overwrite the root nodes
M.name = function(config, node, state)
    if node.type == "directory" and node:get_depth() == 1 then
        if node:has_children() then
            return {
                text = node.name,
                highlight = hl.ROOT_NAME,
            }
        else
            return {
                text = node.name .. " (clean)",
                highlight = hl.GIT_IGNORED,
            }
        end
    end

    return git_status.name(config, node, state)
end

return vim.tbl_deep_extend("force", git_status, M)
