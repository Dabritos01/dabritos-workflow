return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  lazy = false,
  opts = {
    default_file_explorer = true,
    keymaps = {
      ["gy"] = "actions.copy_to_system_clipboard",
      ["gp"] = "actions.paste_from_system_clipboard",
    },
  },
  keys = {
    { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
  },
}
