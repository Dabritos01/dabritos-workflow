local _ws_cache = {}

local function get_workspaces()
  local root = vim.fs.root(0, { "yarn.lock" })
  if not root then return nil, nil end
  if _ws_cache[root] then return root, _ws_cache[root] end

  local output = vim.fn.systemlist("yarn --cwd " .. root .. " workspaces list --json")
  if vim.v.shell_error ~= 0 then return nil, nil end

  local workspaces = {}
  for _, line in ipairs(output) do
    local ok, ws = pcall(vim.json.decode, line)
    if ok and ws and ws.location and ws.location ~= "." then
      table.insert(workspaces, {
        name = ws.name or ws.location,
        path = root .. "/" .. ws.location,
        location = ws.location .. "/",
      })
    end
  end
  -- Sort longest path first for correct prefix matching
  table.sort(workspaces, function(a, b) return #a.path > #b.path end)
  _ws_cache[root] = workspaces
  return root, workspaces
end

local function make_ws_transform()
  local _, workspaces = get_workspaces()
  if not workspaces or #workspaces == 0 then return nil end
  return function(item)
    if not item.file then return item end
    for _, ws in ipairs(workspaces) do
      if item.file:find(ws.location, 1, true) == 1 then
        item.preview_title = ws.name .. " - " .. (item.file:match("[^/]+$") or item.file)
        break
      end
    end
    return item
  end
end

return {
  "folke/snacks.nvim",
  lazy = false,
  priority = 1000,
  ---@type snacks.Config
  opts = {
    picker = {
      enabled = true,
      ui_select = true,
      main = { current = true },
    },
    notifier = { enabled = true, timeout = 5000 },
    bigfile = { enabled = true },
  },
  config = function(_, opts)
    require("snacks").setup(opts)
    vim.notify = require("snacks").notifier.notify
  end,
  keys = {
    -- Find files (supports inline filtering: file:name, path segments, -- -g *.ext)
    { "<leader>ff", function() Snacks.picker.files({ transform = make_ws_transform() }) end, desc = "Find Files" },
    { "<leader>fg", function() Snacks.picker.grep({ transform = make_ws_transform() }) end, desc = "Live Grep" },
    { "<leader>fb", function() Snacks.picker.buffers({ transform = make_ws_transform() }) end, desc = "Buffers" },
    { "<leader>fr", function() Snacks.picker.recent({ transform = make_ws_transform() }) end, desc = "Recent Files" },

    -- Pick a folder and open it in Oil
    {
      "<leader>fo",
      function()
        local dirs = vim.fn.systemlist({ "fd", "--type", "d", "--color", "never", "-E", ".git" })
        local items = {}
        for _, d in ipairs(dirs) do
          table.insert(items, { text = d, file = d })
        end
        Snacks.picker({
          title = "Open folder in Oil",
          items = items,
          confirm = function(picker, item)
            picker:close()
            if item then
              vim.cmd("Oil " .. vim.fn.fnameescape(item.text))
            end
          end,
        })
      end,
      desc = "Find Folder → Open in Oil",
    },

    -- Git
    { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Git Diff (Hunks)" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git Log" },
    { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git Branches" },
    {
      "<leader>gc",
      function()
        local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()
        local files = vim.fn.systemlist({ "git", "-C", root, "diff", "--name-only", "--diff-filter=U" })
        if #files == 0 then
          vim.notify("No merge conflicts", vim.log.levels.INFO)
          return
        end
        local items = {}
        for _, f in ipairs(files) do
          local filepath = root .. "/" .. f
          local lnum = 0
          for line in io.lines(filepath) do
            lnum = lnum + 1
            if line:match("^<<<<<<<") then
              table.insert(items, { text = f .. ":" .. lnum, file = filepath, pos = { lnum, 0 } })
            end
          end
        end
        if #items == 0 then
          vim.notify("No conflict markers found", vim.log.levels.INFO)
          return
        end
        Snacks.picker({
          title = "Merge Conflicts",
          items = items,
          preview = "file",
          confirm = function(picker, item)
            picker:close()
            vim.cmd.edit(item.file)
            vim.api.nvim_win_set_cursor(0, { item.pos[1], 0 })
          end,
        })
      end,
      desc = "Merge Conflicts",
    },

    -- LSP diagnostics
    { "<leader>le", function() Snacks.picker.diagnostics({ severity = vim.diagnostic.severity.ERROR }) end, desc = "LSP Errors" },
    { "<leader>lw", function() Snacks.picker.diagnostics({ severity = vim.diagnostic.severity.WARN }) end, desc = "LSP Warnings" },
    {
      "<leader>ld",
      function()
        Snacks.picker.diagnostics({
          severity = { min = vim.diagnostic.severity.WARN },
          filter = { buf = true },
        })
      end,
      desc = "Buffer Diagnostics (Errors & Warnings)",
    },
    {
      "<leader>la",
      function()
        Snacks.picker.diagnostics({
          severity = { min = vim.diagnostic.severity.WARN },
        })
      end,
      desc = "All Diagnostics (Errors & Warnings)",
    },

    -- Search
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
    { "<leader>sr", function() Snacks.picker.resume() end, desc = "Resume Last Picker" },
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "All Diagnostics" },
    { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },

    -- LSP navigation (these override the lsp.lua keymaps via LspAttach)
    { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
    { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
    { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
    { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto Type Definition" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP Symbols" },

    -- Yarn workspaces
    {
      "<leader>wo",
      function()
        local root = vim.fs.root(0, { "yarn.lock" }) or vim.uv.cwd()
        local output = vim.fn.systemlist("yarn --cwd " .. root .. " workspaces list --json")
        local items = {}
        for _, line in ipairs(output) do
          local ok, ws = pcall(vim.json.decode, line)
          if ok and ws and ws.location and ws.location ~= "." then
            local path = root .. "/" .. ws.location
            table.insert(items, {
              text = (ws.name or ws.location) .. "  " .. ws.location,
              file = path,
              name = ws.name or ws.location,
              location = path,
            })
          end
        end
        if #items == 0 then
          vim.notify("No yarn workspaces found", vim.log.levels.WARN)
          return
        end
        Snacks.picker({
          title = "Yarn Workspace → Oil",
          items = items,
          confirm = function(picker, item)
            picker:close()
            if item then
              vim.cmd("Oil " .. vim.fn.fnameescape(item.location))
            end
          end,
        })
      end,
      desc = "Yarn Workspace → Oil",
    },
    {
      "<leader>wf",
      function()
        local root = vim.fs.root(0, { "yarn.lock" }) or vim.uv.cwd()
        local output = vim.fn.systemlist("yarn --cwd " .. root .. " workspaces list --json")
        local items = {}
        for _, line in ipairs(output) do
          local ok, ws = pcall(vim.json.decode, line)
          if ok and ws and ws.location and ws.location ~= "." then
            local path = root .. "/" .. ws.location
            table.insert(items, {
              text = (ws.name or ws.location) .. "  " .. ws.location,
              file = path,
              name = ws.name or ws.location,
              location = path,
            })
          end
        end
        if #items == 0 then
          vim.notify("No yarn workspaces found", vim.log.levels.WARN)
          return
        end
        Snacks.picker({
          title = "Yarn Workspace → Grep",
          items = items,
          confirm = function(picker, item)
            picker:close()
            if item then
              Snacks.picker.grep({ dirs = { item.location } })
            end
          end,
        })
      end,
      desc = "Yarn Workspace → Grep",
    },
  },
}
