local highlights = require("neo-tree.ui.highlights")
local common = require("neo-tree.sources.common.components")

local M = {}

M.name = function(config, node, state)
    local highlight = config.highlight or highlights.FILE_NAME_OPENED
    local name = node.name
    if node.type == "directory" then
        if node:get_depth() == 1 then
            highlight = highlights.ROOT_NAME
            if node:has_children() then
                name = "GIT STATUS for " .. name
            else
                name = "GIT STATUS (working tree clean) for " .. name
            end
        else
            highlight = highlights.DIRECTORY_NAME
        end
    elseif config.use_git_status_colors then
        local git_status = state.components.git_status({}, node, state)
        if git_status and git_status.highlight then
            highlight = git_status.highlight
        end
    end

    return {
        text = name,
        highlight = highlight,
    }
end

return vim.tbl_deep_extend("force", common, M)
