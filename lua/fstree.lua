require("posixfs")
local fs = posixfs

local VAR_INDENT_SIZE = "fstree_indent_size"
local VAR_CHAR_DIRCLOS = "fstree_char_dirclos"
local VAR_CHAR_DIROPEN = "fstree_char_diropen"

function formatter(api, expanded)
    indent = api.nvim_get_var(VAR_INDENT_SIZE)

    signs = {
        [VAR_CHAR_DIRCLOS] = api.nvim_get_var(VAR_CHAR_DIRCLOS),
        [VAR_CHAR_DIROPEN] = api.nvim_get_var(VAR_CHAR_DIROPEN),
    }

    fmt = {
        [fs.FSITEM_DIR] = function(entry)
            local sign = expanded[entry.id]
                and signs[VAR_CHAR_DIROPEN]
                or signs[VAR_CHAR_DIRCLOS]
            return string.format("%s %s", sign, entry.name)
        end,

        [fs.FSITEM_FILE] = function(entry)
            return string.format("  %s", entry.name)
        end,

        [fs.FSITEM_LINK] = function(entry)
            return string.format("  %s", entry.name)
        end,
    }

    return function(entries)
        local lines = {}
        for i, e in pairs(entries) do
            local indentation = string.rep(' ', indent * e.level)
            lines[#lines + 1] = indentation .. fmt[e.type](e)
        end
        return lines
    end
end

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

-- ============================================================================
-- TODO: move path delimiter to constant
-- TODO: use Type.new instead of Type:new

local function tableid(tab)
    id, _ = string.gsub(tostring(tab), "table: ", "")
    return id
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

-- build new posix path appending the tail to the path
local function join_level(path, tail)
    if tail == ".." then
        return trim_level(path)
    end

    local path, _ = string.gsub(path, "/$", "")
    local tail, _ = string.gsub(tail, "/$", "")
    return string.format("%s/%s", path, tail)
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

-- create filter function from array of exclude patterns
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

-- TODO: it's private function so it should be moved in the insert function
function Tree:shift(position, size)
    for i = position, position + size do
        local e = self.entries[i]
        if e then
            -- self.revers[e.name] = self.revers[e.name] + size
            self.revers[e.id] = self.revers[e.id] + size
        end
    end
end

function Tree:sort(order)
    table.sort(self.entries, order)

    self.revers = {}
    for k, v in pairs(self.entries) do
        -- self.revers[v.name] = k
        self.revers[v.id] = k
    end
end

function Tree:append(entry)
    self.entries[#self.entries + 1] = entry
    -- self.revers[entry.name] = #self.entries
    self.revers[entry.id] = #self.entries
end

function Tree:insert(position, subtree)
    self:shift(position, #subtree.entries)
    insert(self.entries, subtree.entries, position)
end

function Tree:parent(entry)
    local position = self.revers[entry.id]
    for i = position, 1, -1 do
        local e = self.tree[i]
        if e.level < entry.level and e.type == fs.FSITEM_DIR then
            return e
        end
    end
    return nil
end

function Tree:path(entry)
    local parents = {entry}

    while parents[#parents] do
        parents[#parents + 1] = self:parent(parents[#parents])
    end

    local path = ''
    for i = #parents - 1, 1, -1 do
        path = join_level(path, #parents[i])
    end

    local path, _ = string.gsub(path, "^/", "")
    return path
end

-- get ordered array of items in the directory, skip item which names match the
-- exclude pattern
local function scan(dir, expan, filter, level)
    local tree = Tree:new()

    for e in fs.scan(dir) do
        if not filter(e.name) then
            e.level = level
            e.id = tableid(e)
            tree:append(e)
        end
    end

    tree:sort(order)

    for k, v in pairs(expan) do
        local position = tree.revers[k]
        if position then
            local subdir = join_level(dir, v.name)
            local subtree = scan(subdir, expan, filter, level + 1)
            tree:insert(position, subtree)
        end
    end

    return tree
end

Model = {}
Model.__index = Model

function Model.save(api, model)
    api.nvim_set_var("fstree__model", model)
end

function Model.load(api)
    local this = api.nvim_get_var("fstree__model")
    setmetatable(this, Model)
    return this
end

function Model.new(cwd, patterns)
    local this = {}
    setmetatable(this, Model)

    this.cwd = cwd
    this.tree = {entries = {}, revers = {}}
    this.expanded = {}
    this.patterns = patterns

    return this
end

function Model:open(dir)
    local dir = join_level(self.cwd, dir)
    self.tree = scan(dir, self.expanded, filter(self.patterns), 0)
    self.cwd = dir
end

function Model:expand(linenr)
    local entry = self.tree.entries[linenr]

    if entry.type ~= fs.FSITEM_DIR then
        return
    end

    local subdir = join_level(cwd, self.tree:path(entry))
    local subtree = scan(subdir, self.expaned, self.filter, entry.level)

    self.tree:insert(position, subtree)
    self.expanded[entry.id] = true

    return subtree.entries
end

function Model:collapse(linenr)
    error("not implemented")
end

function Model:locate(filename)
    error("not implemented")
end

Controller = {}
Controller.__index = Controller

function Controller.new(api, cwd, model)
    local this = {}
    setmetatable(this, Controller)

    this.cwd = cwd
    this.api = api
    this.model = model
    this.formatter = formatter(api, model.expanded)

    return this
end

function Controller:open()
    self:opendir("")
end

function Controller:next()
    local linenr = self.api.nvim_eval("line('.')")
    local entry = self.model.tree.entries[linenr]

    if entry.type == fs.FSITEM_DIR then
        self:opendir(entry.name)
    else
        self:openfile(entry.name)
    end
end

function Controller:back()
    self:opendir("..")
end

function Controller:opendir(path)
    local buf = self.api.nvim_get_current_buf()
    self.api.nvim_buf_set_lines(buf, 0, #self.model.tree.entries, false, {})

    self.model:open(path)

    local lines = self.formatter(self.model.tree.entries)
    self.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
    local bufname = string.gsub(self.model.cwd, self.cwd .. "/?", "")
    self.api.nvim_buf_set_name(buf, bufname)
end

function Controller:openfile(entry)
    error("not implemented")
end

function Controller:expand(linenr)
    error("not implemented")
end

function Controller:collapse(linenr)
    error("not implemented")
end

function Controller:locate(file)
    error("not implemented")
end

local function load()
    local cwd = vim.api.nvim_get_var('fstree__cwd')
    local model = Model.load(vim.api)
    return Controller.new(vim.api, cwd, model)
end

local function save(cwd, model)
    vim.api.nvim_set_var('fstree__cwd', cwd)
    Model.save(vim.api, model)
end

local function init()
    local cwd = vim.api.nvim_eval("getcwd()")
    local exclude = vim.api.nvim_get_var("fstree_exclude")
    local model = Model.new(cwd, exclude)

    save(cwd, model)

    vim.api.nvim_set_var("fstree_controller", 1)
end

local function open()
    local c = load()
    c:open()
    save(c.cwd, c.model)
end

local function next()
    local c = load()
    c:next()
    save(c.cwd, c.model)
end

local function back()
    local c = load()
    c:back()
    save(c.cwd, c.model)
end

return {
    scan = scan,
    filter = filter,
    insert = insert,
    join_level =  join_level,
    trim_level = trim_level,

    Model = Model,
    Controller = Controller,

    open = open,
    next = next,
    back = back,
    init = init,
}