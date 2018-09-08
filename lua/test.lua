local io = require("io")
local fstree = require("fstree")
local test = require("u-test")
local fs = require("posixfs")

test.insert.middle = function()
    local a = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
    local b = {[1] = "x", [2] = "y"}
    fstree.insert(a, b, 3)

    test.equal(a[1], "a")
    test.equal(a[2], "b")
    test.equal(a[3], "c")
    test.equal(a[4], "x")
    test.equal(a[5], "y")
    test.equal(a[6], "d")
end

test.insert.atend = function()
    local a = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
    local b = {[1] = "x", [2] = "y"}
    fstree.insert(a, b, 4)

    test.equal(a[1], "a")
    test.equal(a[2], "b")
    test.equal(a[3], "c")
    test.equal(a[4], "d")
    test.equal(a[5], "x")
    test.equal(a[6], "y")
end

test.insert.atbegin = function()
    local a = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
    local b = {[1] = "x", [2] = "y"}
    fstree.insert(a, b, 1)

    test.equal(a[1], "a")
    test.equal(a[2], "x")
    test.equal(a[3], "y")
    test.equal(a[4], "b")
    test.equal(a[5], "c")
    test.equal(a[6], "d")
end

test.insert.empty = function()
    local a = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
    local b = {}
    fstree.insert(a, b, 1)

    test.equal(a[1], "a")
    test.equal(a[2], "b")
    test.equal(a[3], "c")
    test.equal(a[4], "d")
end

test.join_level = function()
    test.equal(fstree.join_level("/some/path", "tail"), "/some/path/tail")
    test.equal(fstree.join_level("/some/path/", "tail"), "/some/path/tail")
end

test.trim_level = function()
    test.equal(fstree.trim_level("/some/path/tail"), "/some/path")
    test.equal(fstree.trim_level("/some/path/tail/"), "/some/path")
    test.equal(fstree.trim_level("/some"), "/")
end

local prefix = "/tmp/test/fstree"

local function setup()
    io.popen(string.format("mkdir -p %s/subdir-1", prefix)):close()
    io.popen(string.format("mkdir -p %s/subdir-2", prefix)):close()
    io.popen(string.format("mkdir -p %s/subdir-3", prefix)):close()
    io.popen(string.format("mkdir -p %s/subdir-1/subdir-1-1", prefix)):close()
    io.popen(string.format("mkdir -p %s/subdir-1/subdir-1-2", prefix)):close()
    io.popen(string.format("mkdir -p %s/subdir-3/subdir-3-1", prefix)):close()
    io.popen(string.format("echo file-1 > %s/afile-1", prefix)):close()
    io.popen(string.format("echo file-2 > %s/bfile-2", prefix)):close()
    io.popen(string.format("echo file-1-1 > %s/subdir-1/afile-1-1", prefix)):close()
    io.popen(string.format("echo file-1-2 > %s/subdir-1/afile-1-2", prefix)):close()
    io.popen(string.format("echo file-1-1-1 > %s/subdir-1/subdir-1-1/afile-1-1-1", prefix)):close()
    io.popen(string.format("echo file-1-1-2 > %s/subdir-1/subdir-1-1/afile-1-1-2", prefix)):close()
    io.popen(string.format("echo file-1-1-3 > %s/subdir-1/subdir-1-1/afile-1-1-3", prefix)):close()
    io.popen(string.format("echo file-1-2-1 > %s/subdir-1/subdir-1-2/afile-1-2-1", prefix)):close()
    io.popen(string.format("echo file-1-2-2 > %s/subdir-1/subdir-1-2/afile-1-2-2", prefix)):close()
    io.popen(string.format("echo file-2-1 > %s/subdir-2/zfile-2-1", prefix)):close()
    io.popen(string.format("echo file-2-2 > %s/subdir-2/zfile-2-2", prefix)):close()
    io.popen(string.format("echo file-2-3 > %s/subdir-2/bfile-2-3", prefix)):close()
end

local function teardown()
    io.popen(string.format("rm -rf %s", prefix))
end

test.start_up = setup
test.tear_down = teardown

test.scan = function()
    local filter = fstree.filter({"^%.$", "^%..$"})
    local expand = {"subdir-1", "subdir-3", "subdir-1-1", "subdir-1-2"}
    local tree = fstree.scan(prefix, expand, filter, 0)

    -- for k, v in pairs(entries) do
    --     print(k, string.rep(' ', v.level * 4) .. v.name)
    -- end

    test.equal(tree.entries[1].name, "subdir-1")
    test.equal(tree.entries[2].name, "subdir-1-1")
    test.equal(tree.entries[3].name, "afile-1-1-1")
    test.equal(tree.entries[4].name, "afile-1-1-2")
    test.equal(tree.entries[5].name, "afile-1-1-3")
    test.equal(tree.entries[6].name, "subdir-1-2")
    test.equal(tree.entries[7].name, "afile-1-2-1")
    test.equal(tree.entries[8].name, "afile-1-2-2")
    test.equal(tree.entries[9].name, "afile-1-1")
    test.equal(tree.entries[10].name, "afile-1-2")
    test.equal(tree.entries[11].name, "subdir-2")
    test.equal(tree.entries[12].name, "subdir-3")
    test.equal(tree.entries[14].name, "afile-1")
    test.equal(tree.entries[15].name, "bfile-2")
end

test.summary()
