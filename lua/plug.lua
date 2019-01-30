local string = require("string")
local fs = require("fs")
local tree = require("tree")


local _CREAT = {
    [fs.TYPE.DIR] = fs.mkdir,
    [fs.TYPE.REG] = fs.creat,
}

local _M = {}

--- Create filter function from array of exclude patterns.
-- @param  patterns array: exclude patterns
-- @return function: filter function
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

--- Creates directory scanner with the names filter provided.
-- @param  filter (name) => bool: directory entry name filter
-- @param  order (a, b) => int: sorting order
-- @return (dir, expanded) level) => tree.Tree: directories scanner which
-- expands subdirectories present in expended cache
local function scanner(filter, order)
    local scan
    scan = function(dir, expanded, level)
        local tree = tree.new()

        for e in fs.lsdir(dir) do
            if not filter(e.name) then
                e.level = level
                e.path = fs.join(dir, e.name)
                tree:append(e)
            end
        end

        tree:sort(order)

        for k, v in pairs(expanded) do
            local pos = tree.revers[k]
            if pos then
                local subtree = scan(k, expanded, level + 1)
                tree:insert(pos + 1, subtree)
            end
        end

        return tree
    end
    return scan
end

--- Creaate formatter according to the configuration provieded.
-- @param  cfg table -- configuration with the following keys:
--                      - indent -- indent size
--                      - sign_open -- expanded directory sign
--                      - sign_clos -- collapsed directory sign
-- @return (entry, expanded) => string -- directory entry formatter
local function formatter(cfg, expanded)
    return function(entry)
        local indent = string.rep(" ", cfg.indent * entry.level)

        local sign
        if entry.type == fs.TYPE.DIR then
            sign = expanded[entry.path] and cfg.sign_open or cfg.sign_clos
        else
            sign = " "
        end

        return string.format("%s%s %s", indent, sign, entry.name)
    end
end

--- Create filter function from array of exclude patterns.
-- @param  patterns array: exclude patterns
-- @return function: filter function
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

--- Format tree entries.
-- @param  tree -- directory tree
-- @param  expanded -- cache of expanded directories
-- @param  format -- directory entry formatter
-- @return formatted lines
local function getlines(tree, format)
    local lines = {}
    for k, v in pairs(tree.entries) do
        local line = format(v)
        table.insert(lines, k, line)
    end
    return lines
end


local Plug = {}
Plug.__index = Plug

function Plug.new(view, cwd, cfg)
    local self = setmetatable({}, Plug)
    self.view = view
    self.cfg = cfg
    self.expanded = {}
    self.tree = tree.new()
    self.scan = scanner(filter(cfg.filter), cfg.order)
    self.format = formatter(cfg, self.expanded)
    self:_opendir(cwd)
    return self
end

function Plug:_expand(path, line, level)
    local subtree = self.scan(path, self.expanded, level)
    self.tree:insert(line, subtree)
    local lines = getlines(subtree, self.format)
    self.view:insert(line, lines)
end

function Plug:_opendir(path)
    self.tree:clear()
    self.view:clear()
    self.cwd = path
    self:_expand(path, 1, 0)
    self.view:setname(path)
end

function Plug:_setline(nr, line)
    self.view:remove(nr, 1)
    self.view:insert(nr, {line})
end

function Plug:_rmlines(pos, len)
    self.tree:remove(pos, len)
    self.view:remove(pos, len)
end

function Plug:expand(line)
    local e = self.tree.entries[line]
    if e and e.type == fs.TYPE.DIR then
        self.expanded[e.path] = true
        self:_setline(line, self.format(e))
        self:_expand(e.path, line + 1, e.level + 1)
    end
end

function Plug:collapse(line)
    local e = self.tree.entries[line]
    if e and self.expanded[e.path] then
        self.expanded[e.path] = nil
        local pos = self.tree.revers[e.path]
        self:_setline(pos, self.format(e))
        local len = self.tree:count(e)
        self:_rmlines(pos + 1, len)
    end
end

function Plug:open(line)
    local e = self.tree.entries[line]
    if e then
        if e.type == fs.TYPE.DIR then
            self:_opendir(e.path)
        else
            self.view:bufopen(e.path)
        end
    end
end

function Plug:back()
    self:_opendir(fs.join(self.cwd, ".."))
end

function Plug:creat(line, name, tp)
    local func = _CREAT[tp]
    if not func then
        error(string.format("unkown fs.TYPE %d", tp))
    end

    local e = self.tree.entries[line]
    if e then
        local p = self.tree:parent(e) or { path = self.cwd, level = -1 }
        local path = fs.join(p.path, name)

        func(path)

        local c = {
            [type] = tp,
            name = name,
            path = path,
            level = p.level + 1,
        }

        local k = self.tree:push(p, c, self.cfg.order)
        self.view:insert(k, {self.format(c)})
    end
end

return {new = Plug.new}