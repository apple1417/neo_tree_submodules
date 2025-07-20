local git_status = require("neo-tree.sources.git_status.components")
local hl = require("neo-tree.ui.highlights")

local M = {}

-- we can mostly use the standard git status's components, just need to overwrite the root nodes
M.icon = function(config, node, state)
    if node.id == "neo_tree_submodules:header" then
        return {
            text = "",
            highlight = hl.DIRECTORY_ICON,
        }
    elseif node.id == "neo_tree_submodules:loading" then
        return {
            text = "󱥸",
            highlight = hl.FILE_ICON,
        }
    end

    return git_status.icon(config, node, state)
end

M.name = function(config, node, state)
    if node.id == "neo_tree_submodules:header" then
        return {
            text = node.name,
            highlight = hl.ROOT_NAME,
        }
    elseif node.id == "neo_tree_submodules:loading" then
        return {
            text = node.name,
            highlight = hl.GIT_IGNORED,
        }
    elseif vim.startswith(node.id, "neo_tree_submodules:root") then
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
