require("posixfs")
local fs = posixfs

-- local INDENT_SIZE = vim.api.nvim_get_var('fstree_indent_size')
-- local CHAR_DIRCLOS = vim.api.nvim_get_var('fstree_char_dirclos')
-- local CHAR_DIROPEN = vim.api.nvim_get_var('fstree_char_diropen')

-- local function fmtdir(entry)
--   return string.format("%s %s", CHAR_DIRCLOS, entry.name)
-- end

-- local function fmtfile(entry)
--   return string.format("  %s", entry.name)
-- end

-- local function fmtlink(entry)
--   return string.format("  %s", entry.name)
-- end

-- local FMT = {
--   [fs.FSITEM_DIR] = fmtdir,
--   [fs.FSITEM_FILE] = fmtfile,
--   [fs.FSITEM_LINK] = fmtlink,
-- }

-- local EXCLUDE = {
--   ["."] = true,
--   [".."] = true,
-- }

-- local function order(a, b)
--   if a.type == fs.FSITEM_DIR then
--     if b.type == fs.FSITEM_DIR then
--       return a.name < b.name
--     else
--       return true
--     end
--   else
--     if b.type == fs.FSITEM_DIR then
--       return false
--     else
--       return a.name < b.name
--     end
--   end
-- end

-- local function sort(view)
--   table.sort(view, order)
-- end

-- local function scan(dir, level)
--   local entries = {}
--   for e in fs.scan(dir) do
--     if not EXCLUDE[e.name] then
--       e.level = level
--       entries[#entries + 1] = e
--     end
--   end

--   table.sort(entries, order)

--   -- for e in expanded do
--   --   scan(e, level + 1)
--   -- end

--   return entries
-- end

-- local function joinpath(prefix, tail)
--   -- TODO: do more accurate implementation.
--   return string.format('%s/%s', prefix, tail)
-- end

-- local function indent(line, level)
--   return string.rep(' ', level * INDENT_SIZE) .. line
-- end

-- local function getview()
--   return vim.api.nvim_get_var('fstree_view')
-- end

-- local function setview(view)
--   vim.api.nvim_set_var('fstree_view', view)
-- end

-- function opendir(bufnr, view)
--   -- TODO: set relative path
--   vim.api.nvim_buf_set_lines(bufnr, 0, #view.items, false, {})

--   view.items = {}
--   view.lines = {}

--   vim.api.nvim_buf_set_name(bufnr, view.path)
--   for k, v in pairs(scan(view.path, view.level)) do
--     view.items[#view.items + 1] = v
--     view.lines[#view.lines + 1] = indent(FMT[v.type](v), v.level)
--   end
--   vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, view.lines)

--   setview(view)
-- end

-- function open(bufnr, cwd)
--   local view = {
--     level = 0,
--     items = {},
--     lines = {},
--     expan = {},
--     path = cwd,
--   }
--   opendir(bufnr, view)
-- end

-- function next(bufnr, linenr)
--   local view = getview()
--   local item = view.items[linenr]

--   -- vim.api.nvim_command(string.format('echo "%s"', item.name))

--   if item.type == fs.FSITEM_DIR then
--     view.path = joinpath(view.path, item.name)
--     opendir(bufnr, view)
--   else
--     -- open file
--   end
-- end

-- function back(bufnr)

-- end

-- function locate()
-- end

-- function expand()
-- end

-- function collapse()
-- end

-- return {
--   open = open,
--   next = next,
--   back = back,
--   locate = locate,
--   collapse = collapse,
-- }

-- local function indent(line, level, indent)
--     return string.rep(' ', level * indent) .. line
-- end

-- ============================================================================
-- TODO: move path delimiter to constant

-- build new posix path appending the tail to the path
local function join_level(path, tail)
    local path, _ = string.gsub(path, "/$", "")
    local tail, _ = string.gsub(tail, "/$", "")
    return string.format("%s/%s", path, tail)
end

-- trim one level from the posix path
local function trim_level(path)
    local path, _ = string.gsub(path, "/[^/]+/?$", "")
    if #path == 0 then
        return "/"
    else
        return path
    end
end

-- insert items into array at the given position, existing array elements after
-- the position will be shifted on #items
local function insert(array, items, pos)
    local shift = #items
    for i = #array, pos, -1  do
        array[i + shift] = array[i]
    end
    for k, v in pairs(items) do
        array[k + pos] = v
    end
end

-- defines sorting order of directory items where directories are always on top
-- and all item ordered alphabetically
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

local function filter(patterns)
    return function(name)
        for k, v in pairs(patterns) do
            if string.match(name, v) then
                return true
            end
        end
        return false
    end
end

-- directories and expanded subdirectories list
Tree = {}
Tree.__index = Tree

function Tree:new()
    local this = {}
    setmetatable(this, Tree)
    this.entries = {}
    this.revers = {}
    return this
end

function Tree:shift(position, size)
    for i = position, position + size do
        local e = self.entries[i]
        if e then
            self.revers[e.name] = self.revers[e.name] + size
        end
    end
end

function Tree:sort(order)
    table.sort(self.entries, order)

    self.revers = {}
    for k, v in pairs(self.entries) do
        self.revers[v.name] = k
    end
end

function Tree:append(entry)
    self.entries[#self.entries + 1] = entry
    self.revers[entry.name] = #self.entries
end

function Tree:insert(position, subtree)
    self:shift(position, #subtree.entries)
    insert(self.entries, subtree.entries, position)
end

-- get ordered array of items in the directory, skip item which names match the
-- exclude pattern
local function scan(dir, expan, filter, level)
    local tree = Tree:new()

    for e in fs.scan(dir) do
        if not filter(e.name) then
            e.level = level
            tree:append(e)
        end
    end

    tree:sort(order)

    for k, v in pairs(expan) do
        local position = tree.revers[v]
        if position then
            local subtree = scan(join_level(dir, v), expan, filter, level + 1)
            tree:insert(position, subtree)
        end
    end

    return tree
end

Model = {}
Model.__index = {}

function Model:new(cwd, patterns)
    local m = {}
    setmetatable(m, Model)
    m.cwd = cwd
    m.items = {}
    m.expan = {}
    m.revers = {}
    m.filter = filter(patterns)
    return m
end

function Model:open(dir, level)
end

function Model:expand(dir)

end

function Model:collapse(dir)

end

Controller = {}
Controller.__index = {}

function new(api, cwd)
    local c = {}
    setmetatable(c, Controller)
    c.api = api
    c.model = Model:new(cwd)
    return c
end

return {
    scan = scan,
    filter = filter,
    insert = insert,
    join_level =  join_level,
    trim_level = trim_level,
    Model = Model,
    Controller = Controller,
}