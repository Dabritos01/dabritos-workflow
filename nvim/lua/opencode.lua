local M = {}

local function tmux(args, input)
  local command = { "tmux" }
  vim.list_extend(command, args)
  local output = vim.fn.system(command, input)
  if vim.v.shell_error ~= 0 then
    vim.notify("OpenCode: " .. vim.trim(output), vim.log.levels.ERROR)
    return nil
  end
  return output
end

local function paste(pane, text)
  local buffer = "nvim-opencode-" .. vim.fn.getpid() .. "-" .. vim.uv.hrtime()
  if not tmux({ "load-buffer", "-b", buffer, "-" }, text) then return end
  if not tmux({ "paste-buffer", "-p", "-d", "-b", buffer, "-t", pane.id }) then
    tmux({ "delete-buffer", "-b", buffer })
    return
  end
  tmux({ "select-pane", "-t", pane.id })
end

function M.send_selection()
  if not vim.env.TMUX or not vim.env.TMUX_PANE or vim.fn.executable("tmux") ~= 1 then
    vim.notify("OpenCode: Neovim must be running inside tmux", vim.log.levels.WARN)
    return
  end

  local start = vim.fn.getpos("v")
  local finish = vim.fn.getpos(".")
  local lines = vim.fn.getregion(start, finish, {
    type = vim.fn.mode(),
    exclusive = vim.o.selection == "exclusive",
  })
  local code = table.concat(lines, "\n")
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then path = "[No Name]" end
  local first_line = math.min(start[2], finish[2])
  local last_line = math.max(start[2], finish[2])
  local fence = "```"
  for backticks in code:gmatch("`+") do
    if #backticks >= #fence then fence = string.rep("`", #backticks + 1) end
  end
  local text = string.format("%s:%d-%d\n%s%s\n%s\n%s\n", path, first_line, last_line, fence, vim.bo.filetype, code, fence)
  vim.cmd("normal! \27")

  -- A pane target restricts list-panes to the window containing that pane.
  local output = tmux({ "list-panes", "-t", vim.env.TMUX_PANE, "-F", "#{pane_id}\t#{pane_current_command}\t#{pane_title}" })
  if not output then return end
  local panes = {}
  for line in output:gmatch("[^\n]+") do
    local id, command, title = line:match("^(%%%d+)\t([^\t]+)\t(.*)$")
    if command == "opencode" and id ~= vim.env.TMUX_PANE then
      table.insert(panes, { id = id, title = title })
    end
  end

  if #panes == 0 then
    vim.notify("OpenCode: No OpenCode pane in the current tmux window", vim.log.levels.WARN)
  elseif #panes == 1 then
    paste(panes[1], text)
  else
    vim.ui.select(panes, {
      prompt = "Send selection to OpenCode",
      format_item = function(pane) return pane.id .. " " .. pane.title end,
    }, function(pane)
      if pane then paste(pane, text) end
    end)
  end
end

return M
