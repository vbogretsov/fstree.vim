local io = require("io")

local fs = require("fs")
local order = require("order")
local plug = require("plug")

local test = require("u-test")


test.fs.join = function()
    test.equal(fs.join("/foo/bar", ".."), "/foo")
    test.equal(fs.join("/foo/bar/", ".."), "/foo")
    test.equal(fs.join("/foo", ".."), "/")
    test.equal(fs.join("/foo/", ".."), "/")
    test.equal(fs.join("/", ".."), "/")
    test.equal(fs.join("/foo", "bar"), "/foo/bar")
    test.equal(fs.join("/foo/", "bar"), "/foo/bar")
    test.equal(fs.join("/foo", "bar/"), "/foo/bar")
    test.equal(fs.join("/foo/", "bar/"), "/foo/bar")
    test.equal(fs.join("foo/", "bar/"), "foo/bar")
end

local CWD = "/tmp/fstree"

local function mkdir(path)
    fs.mkdir(fs.join(CWD, path))
end

local function creat(path)
    fs.creat(fs.join(CWD, path))
end

local function start_up()
    fs.mkdir(CWD)

    mkdir("subdir-1")
    mkdir("subdir-1/subdir-1-1")
    mkdir("subdir-1/subdir-1-2")
    mkdir("subdir-2")
    mkdir("subdir-3")
    mkdir("subdir-3/subdir-3-1")
    creat("afile-1")
    creat("bfile-2")
    creat("subdir-1/afile-1-1")
    creat("subdir-1/afile-1-2")
    creat("subdir-1/subdir-1-1/afile-1-1-1")
    creat("subdir-1/subdir-1-1/afile-1-1-2")
    creat("subdir-1/subdir-1-1/afile-1-1-3")
    creat("subdir-1/subdir-1-2/afile-1-2-1")
    creat("subdir-1/subdir-1-2/afile-1-2-2")
    creat("subdir-2/zfile-2-1")
    creat("subdir-2/zfile-2-2")
    creat("subdir-2/bfile-2-3")
end

local function tear_down()
    fs.rmdir(CWD)
end


local View = {
    __eq = function(a, b)
        if a.name ~= b.name then
            return false
        end
        if #a.items ~= #b.items then
            return false
        end

        for i, _ in pairs(a.items) do
            if a.items[i] ~= b.items[i] then
                print(string.format("'%s' ~= '%s'", a.items[i], b.items[i]))
                return false
            end
        end

        return true
    end
}

View.__index = View

function View:__tostring()
    local items = ""
    for k, v in pairs(self.items) do
        items = items .. v .. "\n"
    end
    return string.format("View(name=%s, items={\n%s\n})", self.name, items)
end

function View.new(name, items)
    local self = setmetatable({}, View)
    self.name = name
    self.items = items
    return self
end

function View:insert(line, items)
    for k, v in pairs(items) do
        table.insert(self.items, line + k - 1, v)
    end
end

function View:remove(line, size)
    for i = 1, size do
        local e = table.remove(self.items, line)
    end
end

function View:clear()
    self.items = {}
end

function View:setname(name)
    self.name = name
end

local CFG = {
    filter = {"^%.$", "^%.%.$"},
    order = order.dirontop,
    indent = 2,
    sign_open = "-",
    sign_clos = "+",
}

test.plug.start_up = start_up
test.plug.tear_down = tear_down

test.plug.new = function()
    local v = View.new("", {})
    local p = plug.new(v, CWD, CFG)

    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "+ subdir-2",
        "+ subdir-3",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(3)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "+ subdir-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(2)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(7)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  - subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(1)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  + subdir-1-1",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  - subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(2)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  - subdir-1-1",
        "      afile-1-1-1",
        "      afile-1-1-2",
        "      afile-1-1-3",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  - subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:collapse(14)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  - subdir-1-1",
        "      afile-1-1-1",
        "      afile-1-1-2",
        "      afile-1-1-3",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:collapse(2)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  + subdir-1-1",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(2)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  - subdir-1-1",
        "      afile-1-1-1",
        "      afile-1-1-2",
        "      afile-1-1-3",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:collapse(2)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  + subdir-1-1",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:collapse(2)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  + subdir-1-1",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:collapse(1)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(1)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  + subdir-1-1",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(2)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  - subdir-1-1",
        "      afile-1-1-1",
        "      afile-1-1-2",
        "      afile-1-1-3",
        "  + subdir-1-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(6)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  - subdir-1-1",
        "      afile-1-1-1",
        "      afile-1-1-2",
        "      afile-1-1-3",
        "  - subdir-1-2",
        "      afile-1-2-1",
        "      afile-1-2-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:collapse(1)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

    p:expand(1)
    test.equal(v, View.new(CWD, {
        "- subdir-1",
        "  - subdir-1-1",
        "      afile-1-1-1",
        "      afile-1-1-2",
        "      afile-1-1-3",
        "  - subdir-1-2",
        "      afile-1-2-1",
        "      afile-1-2-2",
        "    afile-1-1",
        "    afile-1-2",
        "- subdir-2",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "- subdir-3",
        "  + subdir-3-1",
        "  afile-1",
        "  bfile-2",
    }))

end

test.plug.open = function()
    local v = View.new("", {})
    local p = plug.new(v, CWD, CFG)

    p:open(1)
    test.equal(v, View.new(fs.join(CWD, "subdir-1"), {
        "+ subdir-1-1",
        "+ subdir-1-2",
        "  afile-1-1",
        "  afile-1-2",
    }))

    p:expand(1)
    test.equal(v, View.new(fs.join(CWD, "subdir-1"), {
        "- subdir-1-1",
        "    afile-1-1-1",
        "    afile-1-1-2",
        "    afile-1-1-3",
        "+ subdir-1-2",
        "  afile-1-1",
        "  afile-1-2",
    }))

    p:back()
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "+ subdir-2",
        "+ subdir-3",
        "  afile-1",
        "  bfile-2",
    }))

    p:open(1)
    test.equal(v, View.new(fs.join(CWD, "subdir-1"), {
        "- subdir-1-1",
        "    afile-1-1-1",
        "    afile-1-1-2",
        "    afile-1-1-3",
        "+ subdir-1-2",
        "  afile-1-1",
        "  afile-1-2",
    }))
end

test.plug.creat = function()
    local v = View.new("", {})
    local p = plug.new(v, CWD, CFG)

    p:expand(2)

    p:creat(3, "afile-9-9", fs.TYPE.REG)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "- subdir-2",
        "    afile-9-9",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "+ subdir-3",
        "  afile-1",
        "  bfile-2",
    }))

    p:creat(1, "afile-9-9", fs.TYPE.REG)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "- subdir-2",
        "    afile-9-9",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "+ subdir-3",
        "  afile-1",
        "  afile-9-9",
        "  bfile-2",
    }))

    p:creat(10, "afile-8-8", fs.TYPE.REG)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "- subdir-2",
        "    afile-9-9",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "+ subdir-3",
        "  afile-1",
        "  afile-8-8",
        "  afile-9-9",
        "  bfile-2",
    }))

    p:creat(2, "subdir-2-4", fs.TYPE.DIR)
    test.equal(v, View.new(CWD, {
        "+ subdir-1",
        "- subdir-2",
        "    afile-9-9",
        "    bfile-2-3",
        "    zfile-2-1",
        "    zfile-2-2",
        "+ subdir-2-4",
        "+ subdir-3",
        "  afile-1",
        "  afile-8-8",
        "  afile-9-9",
        "  bfile-2",
    }))
end