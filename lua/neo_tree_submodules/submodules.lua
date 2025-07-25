local renderer = require("neo-tree.ui.renderer")
local file_items = require("neo-tree.sources.common.file-items")
local utils = require("neo-tree.utils")

local Job = require("plenary.job")
---@class Job
---@field result fun(self: Job): string[]
---@field start fun(self: Job)
---@field on_exit? fun(self: Job, code: number, signal: number)


local M = {}

-- Duplicate this function from neo-tree.git.utils, it's the only one we rely on and we're not
-- supposed to treat that module as public

local convert_octal_char = function(octal)
    return string.char(tonumber(octal, 8))
end

---Converts any octal encoded file paths back to utf8
---@param text string The encoded string to convert
---@return string text The decoded string
M.octal_to_utf8 = function(text)
    local success, converted = pcall(string.gsub, text, "\\([0-7][0-7][0-7])", convert_octal_char)
    if success then
        return converted
    else
        return text
    end
end

---Finds the root of the cwd's git repository
---@param callback fun(git_root: string|nil) Callback to run, passed the path to the git root, or nil on error
M.get_repository_root = function(callback)
    Job:new({
        command = "git",
        args = { "rev-parse", "--show-toplevel" },
        enabled_recording = true,
        ---@param self Job
        ---@param code number
        ---@param _ number
        on_exit = function(self, code, _)
            local git_root = nil

            if code == 0 then
                git_root = self:result()[1]
                git_root = vim.fs.abspath(git_root)

                if utils.is_windows then
                    git_root = utils.windowize_path(git_root)
                end
            end

            vim.schedule(function()
                callback(git_root)
            end)
        end,
    }):start()
end

---@alias StatusPair {path: string, status: string}

---Parses a single git status line
---@param git_root string Root directory of repository
---@param line string The line to parse
---@return StatusPair? status The parsed status, or nil if unable to parse
M.parse_git_status_line = function(line, git_root)
    -- This logic is extracted from parse_git_status_line in neo-tree
    local line_parts = vim.split(line, "\t")
    if #line_parts < 2 then
        return nil
    end
    local status = line_parts[1]
    local relative_path = line_parts[2]

    if status:match("^R") then
        relative_path = line_parts[3]
    end

    relative_path = relative_path:gsub('^"', ""):gsub('"$', "")
    relative_path = M.octal_to_utf8(relative_path)

    if utils.is_windows then
        relative_path = relative_path:gsub("/", "\\")
    end

    local full_path = vim.fs.abspath(
        vim.fs.joinpath(git_root, relative_path)
    )

    if utils.is_windows then
        full_path = utils.windowize_path(full_path)
    end

    return { path=full_path, status=status }
end

---@class StatusJob : Job
---@field statuses table<string, StatusPair[]> A table of submodules to their parsed statuses

---@alias SubmodulePath string
---@alias FilePath string
---@alias FileStatus string
---@alias SubmoduleStatusLookup table<SubmodulePath, table<FilePath, FileStatus>>

---Joins a list of finished status jobs into submodule specific path:status lookup tables
---@param jobs StatusJob[] The list of jobs to join together
---@return SubmoduleStatusLookup statuses The combined status lookup tables
M.join_statuses = function(jobs)
    ---@param accum table<string, StatusPair[]>
    ---@param job StatusJob
    local joined = vim.iter(jobs):fold({}, function(accum, job)
        for submodule, status_pairs in pairs(job.statuses) do
            if accum[submodule] == nil then
                accum[submodule] = status_pairs
            else
                vim.list_extend(accum[submodule], status_pairs)
            end
        end
        return accum
    end)

    ---@param submodule string
    ---@param status_pairs StatusPair[]
    return vim.iter(joined):map(function(submodule, status_pairs)
        local status_lookup = {}

        for _, pair in pairs(status_pairs) do
            local status = pair.status

            -- This merging logic is extracted from parse_git_status_line in neo-tree
            local existing_status = status_lookup[pair.path]
            if existing_status then
                local merged = ""
                local i = 0
                while i < 2 do
                    i = i + 1
                    local existing_char = #existing_status >= i and existing_status:sub(i, i) or ""
                    local new_char = #status >= i and status:sub(i, i) or ""

                    local merged_char
                    if not existing_char then
                        merged_char = new_char
                    elseif not new_char then
                        merged_char = existing_char
                    elseif existing_char == "U" or new_char == "U" then
                        merged_char =  "U"
                    elseif existing_char == "?" or new_char == "?" then
                        merged_char = "?"
                    elseif existing_char == "M" or new_char == "M" then
                        merged_char = "M"
                    elseif existing_char == "A" or new_char == "A" then
                        merged_char = "A"
                    else
                        merged_char = existing_char
                    end

                    merged = merged .. merged_char
                end
                status = merged
            end

            status_lookup[pair.path] = status
        end

        return submodule, status_lookup
    end):fold({}, function(table, key, val)
        table[key] = val
        return table
    end)
end

---Gets the status of all repos under the given root (both the root and all submodules)
---@param git_root string The git repository's root
---@param callback fun(statuses: SubmoduleStatusLookup) Callback passed a map of submodules to a status lookup table inside them
M.submodule_status = function(git_root, callback)
    ---@type StatusJob[]
    local jobs
    local finished_jobs = 0

    local make_on_exit = function(prefix)
        ---@param self StatusJob
        ---@param code number
        ---@param _ number
        return function(self, code, _)
            if code ~= 0 then
                return
            end

            local current_submodule = git_root
            self.statuses[current_submodule] = {}

            vim.iter(self:result()):each(function(line)
                local new_submodule_rel_path = line:match("^Entering '(.+)'$")
                if new_submodule_rel_path ~= nil then
                    current_submodule = vim.fs.joinpath(git_root, new_submodule_rel_path)
 
                    if utils.is_windows then
                        current_submodule = utils.windowize_path(current_submodule)
                    end

                    self.statuses[current_submodule] = {}
                    return
                end

                local status = M.parse_git_status_line(prefix .. line, current_submodule)
                if status ~= nil then
                    table.insert(self.statuses[current_submodule], status)
                end
            end)

            finished_jobs = finished_jobs + 1
            if finished_jobs >= #jobs then
                local statuses = M.join_statuses(jobs)
                vim.schedule(function()
                    callback(statuses)
                end)
            end
        end
    end

    -- Using a submodule foreach to send the same three commands neo-tree used to get statuses
    --
    -- While we could actually use it's function just by passing the paths to each submodule, it's
    -- not a public module, and testing on a big repo I have, running a `git submodule status` takes
    -- about as long as running a status on each submodule (presumably what it does internally)
    --
    -- Doing it this way instead saves doubling up on that time, and also saves us spawning a bunch
    -- of extra processes
    jobs = {
        Job:new({
            command = "git",
            args = { "diff", "--staged", "--name-status" },
            cwd = git_root,
            enabled_recording = true,
            on_exit = make_on_exit(""),
        }),
        Job:new({
            command = "git",
            args = { "submodule", "foreach", "--recursive", "git", "diff", "--staged", "--name-status" },
            cwd = git_root,
            enabled_recording = true,
            on_exit = make_on_exit(""),
        }),
        Job:new({
            command = "git",
            args = { "diff", "--name-status" },
            cwd = git_root,
            enabled_recording = true,
            on_exit = make_on_exit(" "),
        }),
        Job:new({
            command = "git",
            args = { "submodule", "foreach", "--recursive", "git", "diff", "--name-status" },
            cwd = git_root,
            enabled_recording = true,
            on_exit = make_on_exit(" "),
        }),
        Job:new({
            command = "git",
            args = { "ls-files", "--exclude-standard", "--others" },
            cwd = git_root,
            enabled_recording = true,
            on_exit = make_on_exit("?\t"),
        }),
        Job:new({
            command = "git",
            args = { "submodule", "foreach", "--recursive", "git", "ls-files", "--exclude-standard", "--others" },
            cwd = git_root,
            enabled_recording = true,
            on_exit = make_on_exit("?\t"),
        }),
    }

    for _, job in pairs(jobs) do
        job.statuses = {}
        job:start()
    end
end

---Picks unique basename/basename-folder suffixes for a list of paths
---@param paths string[] The list of paths to get unique names for
---@return table<string, string> unique_names A map of the original path to the unique name
M.get_unique_path_names = function(paths)
    local path_data = vim.iter(paths):map(function(path)
        local working_path = path

        -- on windows do both path seperators
        if utils.is_windows then
            working_path = working_path:gsub("/", "\\")
        end

        local parts = vim.iter(vim.split(working_path, utils.path_separator)):rev():totable()
        return { original=path, n = 1, parts=parts }
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
        return data.original, vim.fs.joinpath(unpack(parts))
    end):fold({}, function(table, key, val)
        table[key] = val
        return table
    end)
end

M.draw = function(state)
    if state.loading then
        return
    end
    state.loading = true

    state.default_expanded_nodes = state.default_expanded_nodes or {}
    renderer.show_nodes({
        {
            id = "neo_tree_submodules|loading",
            name = "Loading...",
            type = "directory",
            children = {},
        },
        unpack(state.cached_submodule_nodes or {})
    }, state)

    M.get_repository_root(function(git_root)
        git_root = git_root or state.path or vim.fn.getcwd()
        state.path = git_root

        M.submodule_status(git_root, function(statuses)
            state.default_expanded_nodes = {}

            local names = M.get_unique_path_names(vim.tbl_keys(statuses))
            local nodes = {}

            for submodule_path, status_lookup in vim.spairs(statuses) do
                local context = file_items.create_context()
                context.state = state

                local root = file_items.create_item(context, submodule_path, "directory")
                root.id = "neo_tree_submodules|root|" .. root.id
                root.name = names[submodule_path]
                root.loaded = true
                root.search_pattern = state.search_pattern

                context.folders[root.id] = root
                table.insert(nodes, root)

                for path, status in pairs(status_lookup) do
                    local success, item = pcall(file_items.create_item, context, path, "file")
                    item.status = status
                    if success then
                        item.extra = {
                            git_status = status,
                            submodule = submodule_path,
                        }
                    end
                end

                for id, node in pairs(context.folders) do
                    table.insert(state.default_expanded_nodes, id)
                    node.extra = { submodule = submodule_path }
                end
                file_items.advanced_sort(root.children, state)
            end

            state.git_status_lookup = vim.iter(statuses):map(function(_, status_lookup)
                return status_lookup
            end):fold({}, function(acc, v)
                return vim.tbl_extend("keep", acc, v)
            end)

            state.cached_submodule_nodes = nodes
            renderer.show_nodes({
                {
                    id = "neo_tree_submodules|header",
                    type = "directory",
                    name = "REPOSITORIES under " .. git_root,
                    children = {},
                },
                unpack(nodes),
            }, state)

            state.loading = false
        end)
    end)
end

return M
