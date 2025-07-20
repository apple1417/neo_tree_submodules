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
