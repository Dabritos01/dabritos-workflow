local _ws_cache = {}

-- Drop the workspace cache. Pass a root to clear just that repo, or nil for all.
local function clear_ws_cache(root)
  if root then
    _ws_cache[root] = nil
  else
    _ws_cache = {}
  end
end

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

local function get_local_dir()
  if vim.bo.filetype == "oil" then
    return require("oil").get_current_dir()
  end
  local file = vim.api.nvim_buf_get_name(0)
  return (file ~= "" and vim.fs.dirname(file)) or vim.uv.cwd()
end

-- Present a picker of yarn workspaces; calls on_confirm(item) with the chosen one.
-- item fields: name, path (absolute dir), location (relative dir + trailing slash).
local function pick_workspace(title, on_confirm)
  local _, workspaces = get_workspaces()
  if not workspaces or #workspaces == 0 then
    vim.notify("No yarn workspaces found", vim.log.levels.WARN)
    return
  end
  local items = {}
  for _, ws in ipairs(workspaces) do
    table.insert(items, {
      text = ws.name .. "  " .. ws.location,
      file = ws.path,
      name = ws.name,
      path = ws.path,
      location = ws.location,
    })
  end
  Snacks.picker({
    title = title,
    items = items,
    confirm = function(picker, item)
      picker:close()
      if item then on_confirm(item) end
    end,
  })
end

-- Map of location -> workspace object (incl. workspaceDependencies) from yarn's verbose output.
local function get_workspaces_verbose(root)
  local output = vim.fn.systemlist("yarn --cwd " .. root .. " workspaces list --json -v")
  if vim.v.shell_error ~= 0 then return nil end
  local by_location = {}
  for _, line in ipairs(output) do
    local ok, ws = pcall(vim.json.decode, line)
    if ok and ws and ws.location then
      by_location[ws.location] = ws
    end
  end
  return by_location
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

    -- Show the owning yarn workspace in the winbar for files inside a monorepo
    local ws_group = vim.api.nvim_create_augroup("WorkspaceWinbar", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
      group = ws_group,
      callback = function(ev)
        if vim.bo[ev.buf].buftype ~= "" then return end
        local file = vim.api.nvim_buf_get_name(ev.buf)
        if file == "" then return end
        local _, workspaces = get_workspaces()
        local label
        if workspaces then
          local tail = vim.fn.fnamemodify(file, ":t")
          for _, ws in ipairs(workspaces) do
            if file:find(ws.path, 1, true) == 1 then
              label = "%#Comment#" .. ws.name .. "%* › " .. tail
              break
            end
          end
        end
        vim.wo.winbar = label or ""
      end,
    })

    -- Invalidate the workspace cache when the workspace graph changes
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = ws_group,
      pattern = "yarn.lock",
      callback = function()
        clear_ws_cache()
      end,
    })
  end,
  keys = {
    -- Find files (supports inline filtering: file:name, path segments, -- -g *.ext)
    { "<leader>ff", function() Snacks.picker.files({ transform = make_ws_transform() }) end, desc = "Find Files" },
    {
      "<leader>flf",
      function() Snacks.picker.files({ cwd = get_local_dir(), title = "Find Local Files" }) end,
      desc = "Find Local Files",
    },
    { "<leader>flg", function() Snacks.picker.grep({ cwd = get_local_dir(), title = "Grep Local" }) end, desc = "Grep Local" },
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
          if vim.fn.filereadable(filepath) == 1 then
            -- File present in the working tree: locate its conflict markers.
            local lnum = 0
            for line in io.lines(filepath) do
              lnum = lnum + 1
              if line:match("^<<<<<<<") then
                table.insert(items, {
                  text = f .. ":" .. lnum,
                  file = filepath,
                  pos = { lnum, 0 },
                  preview = "file",
                })
              end
            end
          else
            -- File is gone from the working tree (e.g. delete/delete conflict):
            -- fall back to the common-ancestor version from git stage 1.
            local raw = vim.fn.system({ "git", "-C", root, "show", ":1:" .. f })
            local ok = vim.v.shell_error == 0
            local binary = ok and raw:find("\0", 1, true) ~= nil
            local base_lines, ft, preview
            if not ok then
              base_lines = { "No base version available for: " .. f }
              preview = { text = base_lines[1] }
            elseif binary then
              base_lines = { "Binary file (deleted on both sides):", f }
              preview = { text = table.concat(base_lines, "\n") }
            else
              base_lines = vim.split(raw, "\n")
              ft = vim.filetype.match({ filename = f })
              preview = { text = raw, ft = ft }
            end
            table.insert(items, {
              text = "[deleted] " .. f,
              deleted = true,
              rel = f,
              ft = ft,
              base_lines = base_lines,
              preview = preview,
            })
          end
        end
        if #items == 0 then
          vim.notify("No conflict markers found", vim.log.levels.INFO)
          return
        end
        Snacks.picker({
          title = "Merge Conflicts",
          items = items,
          preview = "preview",
          confirm = function(picker, item)
            picker:close()
            if not item then return end
            if item.deleted then
              -- Show the base (stage 1) content in a read-only scratch buffer.
              local buf = vim.api.nvim_create_buf(false, true)
              vim.api.nvim_buf_set_lines(buf, 0, -1, false, item.base_lines)
              vim.bo[buf].buftype = "nofile"
              vim.bo[buf].bufhidden = "wipe"
              vim.bo[buf].modifiable = false
              if item.ft then vim.bo[buf].filetype = item.ft end
              pcall(vim.api.nvim_buf_set_name, buf, "conflict-base://" .. item.rel)
              vim.api.nvim_win_set_buf(0, buf)
            else
              vim.cmd.edit(item.file)
              vim.api.nvim_win_set_cursor(0, { item.pos[1], 0 })
            end
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
      "<leader>wr",
      function()
        clear_ws_cache()
        local _, workspaces = get_workspaces()
        vim.notify("Refreshed " .. (workspaces and #workspaces or 0) .. " yarn workspaces", vim.log.levels.INFO)
      end,
      desc = "Yarn Workspace → Refresh Cache",
    },
    { "<leader>wf", function() pick_workspace("Yarn Workspace → Find Files", function(item) Snacks.picker.files({ dirs = { item.path }, transform = make_ws_transform() }) end) end, desc = "Yarn Workspace → Find Files" },
    { "<leader>wg", function() pick_workspace("Yarn Workspace → Grep", function(item) Snacks.picker.grep({ dirs = { item.path }, transform = make_ws_transform() }) end) end, desc = "Yarn Workspace → Grep" },
    { "<leader>wo", function() pick_workspace("Yarn Workspace → Oil", function(item) vim.cmd("Oil " .. vim.fn.fnameescape(item.path)) end) end, desc = "Yarn Workspace → Oil" },
    {
      "<leader>wd",
      function()
        pick_workspace("Yarn Workspace → Dependencies", function(item)
          local root = vim.fs.root(0, { "yarn.lock" }) or vim.uv.cwd()
          local by_location = get_workspaces_verbose(root)
          if not by_location then
            vim.notify("Could not read workspace dependencies", vim.log.levels.ERROR)
            return
          end
          local ws = by_location[(item.location:gsub("/$", ""))]
          local deps = ws and ws.workspaceDependencies or {}
          if #deps == 0 then
            vim.notify(item.name .. " has no workspace dependencies", vim.log.levels.INFO)
            return
          end
          local dep_items = {}
          for _, dep_loc in ipairs(deps) do
            local dep = by_location[dep_loc]
            local name = dep and dep.name or dep_loc
            table.insert(dep_items, {
              text = name .. "  " .. dep_loc,
              file = root .. "/" .. dep_loc,
              path = root .. "/" .. dep_loc,
              name = name,
            })
          end
          Snacks.picker({
            title = item.name .. " → Dependencies",
            items = dep_items,
            confirm = function(picker, dep)
              picker:close()
              if dep then vim.cmd("Oil " .. vim.fn.fnameescape(dep.path)) end
            end,
          })
        end)
      end,
      desc = "Yarn Workspace → Dependencies",
    },
  },
}
