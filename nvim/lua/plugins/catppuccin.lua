return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  opts = {
    flavour = "mocha",
    integrations = {
      oil = true,
    },
    custom_highlights = function(colors)
      return {
        LineNr = { fg = colors.teal },
        CursorLineNr = { fg = colors.peach, bold = true, style = { "bold" } },
        CursorLine = { bg = colors.surface0 },
      }
    end,
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
  end,
}
