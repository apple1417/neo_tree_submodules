# NOT MAINTAINED

I'm not actively maintaining this plugin.

Since [this neo-tree commit](https://github.com/nvim-neo-tree/neo-tree.nvim/commit/e4b35ec43d), this
plugin no longer properly displays the git status - though it still works otherwise, it only lists
modified files and add/remove/commit all still work. This is cause it pokes into neo-tree's
internals a bit more than is guarenteed to be stable.

If you want to use this plugin (and don't want to update it yourself), I recommend pinning neo-tree
to a version just before this:
```lua
    {
        "nvim-neo-tree/neo-tree.nvim",
        commit = "a981ef287503c668434bffa78071d5b9ff92c12f",
        ...
    }
```

# Neo-tree submodules
Git status viewer for [Neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim), which also shows
changes in submodules. Inspired by VSCode.

<img width="360" height="177" alt="image" src="https://github.com/user-attachments/assets/cfb6be40-2768-43a2-ad6f-e0e2eb9934c5" />

## Installation

<details>
<summary>lazy.nvim</summary>

```lua
return {
    {
        "apple1417/neo_tree_submodules",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        lazy = true,
    },
    {
        "nvim-neo-tree/neo-tree.nvim", branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
            -- append this as a dependency
            "apple1417/neo_tree_submodules",
        },
        opts = {
            sources = {
                "filesystem",
                "buffers",
                "git_status",
                -- append this source
                "neo_tree_submodules",
            },
            source_selector = {
                sources = {
                    { source = "filesystem" },
                    { source = "buffers" },
                    { source = "git_status" },
                    -- append this source
                    { source = "neo_tree_submodules" },
                },
            },
            -- add source specific settings
            neo_tree_submodules = {
                window = {
                    mappings = {
                        -- custom mappings
                    },
                },
            },
        },
    },
}
```

</details>
