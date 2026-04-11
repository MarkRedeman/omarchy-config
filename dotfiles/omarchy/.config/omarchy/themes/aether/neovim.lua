return {
    {
        "bjarneo/aether.nvim",
        name = "aether",
        priority = 1000,
        opts = {
            disable_italics = false,
            colors = {
                -- Monotone shades (base00-base07)
                base00 = "#07070B", -- Default background
                base01 = "#353543", -- Lighter background (status bars)
                base02 = "#07070B", -- Selection background
                base03 = "#353543", -- Comments, invisibles
                base04 = "#D7A88D", -- Dark foreground
                base05 = "#f0dbcf", -- Default foreground
                base06 = "#f0dbcf", -- Light foreground
                base07 = "#D7A88D", -- Light background

                -- Accent colors (base08-base0F)
                base08 = "#DD5C5C", -- Variables, errors, red
                base09 = "#f0a5a5", -- Integers, constants, orange
                base0A = "#b4b691", -- Classes, types, yellow
                base0B = "#9CAB8D", -- Strings, green
                base0C = "#abc8c9", -- Support, regex, cyan
                base0D = "#9a9dbc", -- Functions, keywords, blue
                base0E = "#c09dc8", -- Keywords, storage, magenta
                base0F = "#dadcc7", -- Deprecated, brown/yellow
            },
        },
        config = function(_, opts)
            require("aether").setup(opts)
            vim.cmd.colorscheme("aether")

            -- Enable hot reload
            require("aether.hotreload").setup()
        end,
    },
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "aether",
        },
    },
}
