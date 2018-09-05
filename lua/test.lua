require "table"
require "posixfs"

fs = posixfs

function fmtdir(entry)
  return string.format("%s %s", "D", entry.name)
end

function fmtfile(entry)
  return string.format("%s", entry.name)
end

function fmtlink(entry)
  return string.format("%s", entry.name)
end

fmt = {
  [fs.FSITEM_DIR] = fmtdir,
  [fs.FSITEM_FILE] = fmtfile,
  [fs.FSITEM_LINK] = fmtlink,
}

lines = {}
for entry in fs.scan("/Users/vova") do
  -- print(string.format("%s %s", line.type, line.name))
  -- print(fmt[entry.type](entry))
  -- lines[#lines + 1] = fmt[entry.type](entry)
  lines[#lines + 1] = entry
end

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

table.sort(lines, order)

for k, v in pairs(lines) do
  print(fmt[v.type](v))
end


