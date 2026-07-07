-- Blend the current-line blame color 10% toward the Normal foreground so the
-- blame virtual text reads a touch more opaque/visible.
local blame_base_fg = nil

local function brighten_blame()
  local blame = vim.api.nvim_get_hl(0, { name = "GitSignsCurrentLineBlame", link = false })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  if not (blame.fg and normal.fg) then return end

  -- Capture the theme's original dim color once so repeated calls don't compound.
  blame_base_fg = blame_base_fg or blame.fg

  local bit = require("bit")
  local function mix(base, target, t)
    return math.floor(base + (target - base) * t + 0.5)
  end
  local function split(c)
    return bit.band(bit.rshift(c, 16), 0xff), bit.band(bit.rshift(c, 8), 0xff), bit.band(c, 0xff)
  end
  local br, bg, bb = split(blame_base_fg)
  local nr, ng, nb = split(normal.fg)
  local r = mix(br, nr, 0.2)
  local g = mix(bg, ng, 0.2)
  local bl = mix(bb, nb, 0.2)

  vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { fg = bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), bl) })
end

return {
  "lewis6991/gitsigns.nvim",
  event = "VeryLazy",
  config = function(_, opts)
    require("gitsigns").setup(opts)
    brighten_blame()
    -- Re-derive the base and re-apply when the colorscheme changes.
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        blame_base_fg = nil
        brighten_blame()
      end,
    })
  end,
  opts = {
    signs = {
      add = { text = "┃" },
      change = { text = "┃" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "┆" },
    },
    current_line_blame = true,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol",
      delay = 250,
    },
    on_attach = function(bufnr)
      local gs = require("gitsigns")

      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end

      -- Navigation
      map("n", "]c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gs.nav_hunk("next")
        end
      end, "Next Hunk")

      map("n", "[c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gs.nav_hunk("prev")
        end
      end, "Previous Hunk")

      -- Actions
      map("n", "<leader>hs", gs.stage_hunk, "Stage Hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset Hunk")
      map("v", "<leader>hs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage Selection")
      map("v", "<leader>hr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Reset Selection")
      map("n", "<leader>hS", gs.stage_buffer, "Stage Buffer")
      map("n", "<leader>hR", gs.reset_buffer, "Reset Buffer")
      map("n", "<leader>hu", gs.undo_stage_hunk, "Undo Stage Hunk")
      map("n", "<leader>hp", gs.preview_hunk, "Preview Hunk")
      map("n", "<leader>hb", function()
        gs.blame_line({ full = true })
      end, "Blame Line")
      map("n", "<leader>hd", gs.diffthis, "Diff This")
      map("n", "<leader>ht", gs.toggle_current_line_blame, "Toggle Line Blame")
    end,
  },
}
