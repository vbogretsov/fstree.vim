local fs = require("fs")


local Tree = {}
Tree.__index = Tree

function Tree.new()
    local self = setmetatable({}, Tree)

    self.entries = {}
    self.revers = {}

    return self
end

--- Sort tree items using the order function provided.
-- @param  order (a, b) => int: comparator defining sorting order
function Tree:sort(order)
    table.sort(self.entries, order)

    self.revers = {}
    for k, v in pairs(self.entries) do
        self.revers[v.path] = k
    end
end

--- Adds an entry after the last position.
-- @param  entry table: entry to be added
function Tree:append(entry)
    self.entries[#self.entries + 1] = entry
    self.revers[entry.path] = #self.entries
end

--- Inserts new items starting from the position provided.
-- @param  pos number: position of the first item in the new set
-- @param  new array: new items to be inserted
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

--- Removes len entries from the tree starting from the position pos.
-- @param  pos number: remove items starting from this position
-- @param  len number: how many items should be removed
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

--- Remove all items from the tree.
function Tree:clear()
    self.tree = {}
    self.revers = {}
end

function Tree:push(parent, item, order)
    local k = -1

    local n = self.revers[parent.path]
    if not n then
        return k
    end

    for i = n + 1, #self.entries do
        local e = self.entries[i]
        if e.level >= parent.level then
            break
        end
        if order(item, e) then
            k = i
            table.insert(self.entries, k, item)
            break
        end
    end

    return k
end

--- Get parent entry of the provided one.
-- @param  entry table: entry which parent is requested
function Tree:parent(entry)
    local pos = self.revers[entry.path]
    for i = pos, 1, -1 do
        local e = self.entries[i]
        if e.level < entry.level and e.type == fs.TYPE.DIR then
            return e
        end
    end
    return nil
end

--- Count child items in the entry.
-- @param  entry table: entry which child items should be counted
-- @return 0 if entriy is not a directory else number of directory items
function Tree:count(entry)
    local cnt = 0
    for i = self.revers[entry.path] + 1, #self.entries do
        if self.entries[i].level <= entry.level then
            break
        end
        cnt = cnt + 1
    end
    return cnt
end

return {new = Tree.new}