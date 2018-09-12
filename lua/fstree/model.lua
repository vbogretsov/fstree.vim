--- model: provides vim and fs agnostic fs tree navigation
local fs = require("posixfs")

--- defines sorting order of directory items where directories are always on
-- top and all items ordered alphabetically
-- @param a table: left value
-- @param b table: right value
-- @return bool: true if a < b, otherwise false
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

--- represents directories and expanded subdirectories list and provides
-- operations to manipulate and navigate items
local Tree = {}
Tree.__index = Tree

function Tree.new()
    local self = setmetatable({}, Tree)

    self.entries = {}
    self.revers = {}

    return self
end

--- sort tree items in alphabetical order but directories are always on top
-- @param order function: comparator defining sorting order
function Tree:sort(order)
    table.sort(self.entries, order)

    self.revers = {}
    for k, v in pairs(self.entries) do
        self.revers[v.path] = k
    end
end

--- adds an entry after the last position
-- @param entry table: entry to be added
function Tree:append(entry)
    self.entries[#self.entries + 1] = entry
    self.revers[entry.path] = #self.entries
end

--- inserts new items starting from the position provided
-- @param pos number: position of the first item in the new set
-- @param new array: new items to be inserted
function Tree:insert(pos, new)
    for k, v in pairs(new.entries) do
        local i = pos + k - 1
        table.insert(self.entries, i, v)
        self.revers[v.path] = i
    end

    for i = pos + #new, #self.entries do
        self.revers[self.entries[i].path] = i
    end
end

--- removes len entries from the tree starting from the position pos
-- @param pos number: remove items starting from this position
-- @param len number: how many items should be removed
function Tree:remove(pos, len)
    for i = 1, len do
        local e = table.remove(self.entries, pos)
        self.revers[e.path] = nil
    end

    for i = pos, #self.entries do
        local id = self.entries[i].path
        self.revers[id] = self.revers[id] - len
    end
end

--- get parent entry of the provided one
-- @param entry table: entry which parent is requested
function Tree:parent(entry)
    local pos = self.revers[entry.id]
    for i = pos, 1, -1 do
        local e = self.entries[i]
        if e.level < entry.level and e.type == fs.FSITEM_DIR then
            return e
        end
    end
    return nil
end

-- TODO: remove if unnecessary
--- gets list of parent nodes of the entry provided
-- @param entry table: the entry which parents are requested
-- @return array: entry's parents
function Tree:path(entry)
    local parents = {entry}

    while true do
        local parent = self:parent(parents[1])
        if parent == nil then
            break
        end
        table.insert(parents, 1, parent)
    end

    return parents
end

--- create filter function from array of exclude patterns
-- @param patterns array: exclude patterns
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

local function scanner(expanded, filter)
    local scan
    scan = function(dir, level)
        local tree = Tree:new()

        for e in fs.scan(dir) do
            if not filter(e.name) then
                e.level = level
                e.path = fs.path_join(dir, e.name)
                tree:append(e)
            end
        end

        tree:sort(order)

        for k, v in pairs(expanded[dir] or {}) do
            local sub = fs.path_join(dir, k)
            local pos = tree.revers[sub]

            if pos then
                local subtree = scan(sub, level + 1)
                tree:insert(pos + 1, subtree)
            end
        end

        return tree
    end
    return scan
end

--- get ordered directory tree
-- @param dir string: directory path
-- @param expanded table: cache of entries which should be expanded
-- @param filter function: filter function
-- @param level number: directory level
-- local function scan(dir, expanded, filter, level)
--     local tree = Tree:new()

--     for e in fs.scan(dir) do
--         if not filter(e.name) then
--             e.level = level
--             tree:append(e)
--         end
--     end

--     tree:sort(order)

--     for k, v in pairs(expanded) do
--         local pos = tree.revers[k]
--         if pos then
--             local subdir = fs.path_join(dir, v.name)
--             local subtree = scan(subdir, expanded, filter, level + 1)
--             tree:insert(pos, subtree)
--         end
--     end

--     return tree
-- end

--- represents plugin model
Model = {}
Model.__index = Model

function Model.new(cwd, patterns)
    local self = setmetatable({}, Model)

    this.cwd = cwd
    this.tree = Tree.new()
    this.expanded = {}
    this.patterns = patterns

    return this
end

function Model:open(dir)
    local dir = fs.path_join(self.cwd, dir)
    self.tree = scan(dir, self.expanded, filter(self.patterns), 0)
    self.cwd = dir
    return tree.entrie
end

function Model:expand(entry)

    local subdir = fs.path_join(self.cwd, self.tree:path(entry))
    local filter = filter(self.patterns)
    local subtree = scan(subdir, self.expanded, filter, entry.level + 1)

    self.tree:insert(linenr, subtree)
    self.expanded[entry.path] = true

    return subtree.entries
end

return {
    Tree = Tree,
    filter = filter,
    scanner = scanner,
}