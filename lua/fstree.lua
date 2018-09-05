require "posixfs"

local fs = posixfs

local INDENT_SIZE = vim.api.nvim_get_var('fstree_indent_size')
local CHAR_DIRCLOS = vim.api.nvim_get_var('fstree_char_dirclos')
local CHAR_DIROPEN = vim.api.nvim_get_var('fstree_char_diropen')

local function fmtdir(entry)
  return string.format("%s %s", CHAR_DIRCLOS, entry.name)
end

local function fmtfile(entry)
  return string.format("  %s", entry.name)
end

local function fmtlink(entry)
  return string.format("  %s", entry.name)
end

local FMT = {
  [fs.FSITEM_DIR] = fmtdir,
  [fs.FSITEM_FILE] = fmtfile,
  [fs.FSITEM_LINK] = fmtlink,
}

local EXCLUDE = {
  ["."] = true,
  [".."] = true,
}

local function order(a, b)
  if a.type == fs.FSITEM_DIR then
    if b.type == fs.FSITEM_DIR then
      return a.name < b.name
    else
      return true
    end
  else
    if b.type == fs.FSITEM_DIR then
      return false
    else
      return a.name < b.name
    end
  end
end

local function sort(view)
  table.sort(view, order)
end

local function scan(dir, level)
  local entries = {}
  for e in fs.scan(dir) do
    if not EXCLUDE[e.name] then
      e.level = level
      entries[#entries + 1] = e
    end
  end

  table.sort(entries, order)

  -- for e in expanded do
  --   scan(e, level + 1)
  -- end

  return entries
end

local function indent(line, level)
  return string.rep(' ', level * INDENT_SIZE) .. line
end

function open(bufnr, cwd)
  vim.api.nvim_buf_set_name(bufnr, cwd)

  local lines ={}
  for k, v in pairs(scan(cwd, 0)) do
    lines[#lines + 1] = indent(FMT[v.type](v), v.level)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, lines)
end

function enter(bufnr, linenr)

end

return {
  open = open,
  enter = enter,
}