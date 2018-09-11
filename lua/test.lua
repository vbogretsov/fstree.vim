local io = require("io")
local test = require("u-test")
local fs = require("posixfs")
local model = require("fstree.model")

-- ************************** fixtures ****************************************

local CWD = "/tmp/test/fstree"

local function mkdir(path)
    io.popen(string.format("mkdir -p %s/%s", CWD, path)):close()
end

local function echo(content, path)
    io.popen(string.format("echo %s > %s/%s", content, CWD, path)):close()
end

local function start_up()
    mkdir("subdir-1")
    mkdir("subdir-1/subdir-1-1")
    mkdir("subdir-1/subdir-1-2")
    mkdir("subdir-2")
    mkdir("subdir-3")
    mkdir("subdir-3/subdir-3-1")
    echo("file-1", "afile-1")
    echo("file-2", "bfile-2")
    echo("file-1-1", "subdir-1/afile-1-1")
    echo("file-1-2", "subdir-1/afile-1-s")
    echo("file-1-1-1", "subdir-1/subdir-1-1/afile-1-1-1")
    echo("file-1-1-2", "subdir-1/subdir-1-1/afile-1-1-2")
    echo("file-1-1-3", "subdir-1/subdir-1-1/afile-1-1-3")
    echo("file-1-2-1", "subdir-1/subdir-1-2/afile-1-2-1")
    echo("file-1-2-2", "subdir-1/subdir-1-2/afile-1-2-2")
    echo("file-2-1", "subdir-2/zfile-2-1")
    echo("file-2-2", "subdir-2/zfile-2-2")
    echo("file-2-3", "subdir-2/bfile-2-3")
end

local function tear_down()
    io.popen(string.format("rm -rf %s", CWD))
end

-- ************************** posixfs *****************************************

test.fs.path_join = function()
    test.equal(fs.path_join("/foo/bar", ".."), "/foo")
    test.equal(fs.path_join("/foo/bar/", ".."), "/foo")
    test.equal(fs.path_join("/foo", ".."), "/")
    test.equal(fs.path_join("/foo/", ".."), "/")
    test.equal(fs.path_join("/", ".."), "/")
    test.equal(fs.path_join("/foo", "bar"), "/foo/bar")
    test.equal(fs.path_join("/foo/", "bar"), "/foo/bar")
    test.equal(fs.path_join("/foo", "bar/"), "/foo/bar")
    test.equal(fs.path_join("/foo/", "bar/"), "/foo/bar")
    test.equal(pcall(function() fs.path_join("foo/", "bar") end), false)
    test.equal(pcall(function() fs.path_join("/foo", "/bar") end), false)
    test.equal(pcall(function() fs.path_join("", "bar") end), false)
end

test.fs.start_up = start_up
test.fs.tear_down = tear_down

test.fs.scan = function()
    local entries = {
        [fs.FSITEM_DIR] = {},
        [fs.FSITEM_FILE] = {},
        [fs.FSITEM_LINK] = {}
    }

    for e in fs.scan(CWD) do
        entries[e.type][e.name] = true
    end

    test.is_true(entries[fs.FSITEM_DIR]["subdir-1"])
    test.is_true(entries[fs.FSITEM_DIR]["subdir-2"])
    test.is_true(entries[fs.FSITEM_DIR]["subdir-3"])
    test.is_true(entries[fs.FSITEM_FILE]["afile-1"])
    test.is_true(entries[fs.FSITEM_FILE]["bfile-2"])
end

test.open.start_up = start_up
test.open.tear_down = tear_down

-- ************************** mock ********************************************

local Mock = {}
Mock.__index = Mock

function Mock.new()
    local self = setmetatable({}, Mock)
    self.buf = 1
    self.bufs = {
        [self.buf] = {lines = {}, name = ""}
    }
    self.vars = {
        fstree_indent_size = 2,
        fstree_char_dirclos = "+",
        fstree_char_diropen = "-",
    }
    self.line = 1
    return self
end

function Mock:linenr()
    return self.line
end

function Mock:bufnr()
    return self.buf
end

function Mock:buf_set_name(bufnr, name)
    self.bufs[bufnr].name = name
end

function Mock:buf_set_lines(bufnr, lines)
    self.bufs[bufnr].lines = lines
end

function Mock:buf_insert_lines(bufnr, pos, lines)
    for i = 1, #lines do
        table.insert(self.bufs[bufnr].lines, pos + i - 1, lines[i])
    end
end

function Mock:buf_remove_lines(bufnr, pos, len)
    for i = 1, len do
        table.remove(self.bufs[bufnr].lines, pos)
    end
end

function Mock:get_var(name)
    return self.vars[name]
end

-- ************************** fstree ******************************************

local function setup_tree()
    local a = model.Tree.new()
    for i = 1, 10 do
        a:append({name = "a" .. i, type = fs.FSITEM_FILE})
    end

    local b = model.Tree.new()
    for i = 1, 5 do
        b:append({name = "b" .. i, type = fs.FSITEM_DIR})
    end

    return a, b
end

test.tree.insert = function()
    local a, b = setup_tree()
    local len_a = #a.entries
    local len_b = #b.entries

    a:insert(4, b)

    test.equal(len_a + len_b, #a.entries)
    test.equal(a.entries[1].name, "a1")
    test.equal(a.entries[2].name, "a2")
    test.equal(a.entries[3].name, "a3")
    test.equal(a.entries[4].name, "b1")
    test.equal(a.entries[5].name, "b2")
    test.equal(a.entries[6].name, "b3")
    test.equal(a.entries[7].name, "b4")
    test.equal(a.entries[8].name, "b5")
    test.equal(a.entries[9].name, "a4")
    test.equal(a.entries[10].name, "a5")
    test.equal(a.entries[11].name, "a6")
    test.equal(a.entries[12].name, "a7")
    test.equal(a.entries[13].name, "a8")
    test.equal(a.entries[14].name, "a9")
    test.equal(a.entries[15].name, "a10")

    for i = 1, #a.entries do
        local id, _ = string.gsub(tostring(a.entries[i]), "table: ", "")
        test.equal(a.revers[id], i)
    end
end

test.tree.remove = function()
    local a, _ = setup_tree()
    local len_a = #a.entries

    a:remove(4, 5)

    test.equal(len_a - 5, #a.entries)
    test.equal(a.entries[1].name, "a1")
    test.equal(a.entries[2].name, "a2")
    test.equal(a.entries[3].name, "a3")
    test.equal(a.entries[4].name, "a9")
    test.equal(a.entries[5].name, "a10")

    for i = 1, #a.entries do
        local id, _ = string.gsub(tostring(a.entries[i]), "table: ", "")
        test.equal(a.revers[id], i)
    end
end

test.mock.bufnr = function()
    local mock = Mock.new()
    test.equal(mock:bufnr(), 1)
end

test.mock.linenr = function()
    local mock = Mock.new()
    test.equal(mock:linenr(), 1)
    mock.line = 2
    test.equal(mock:linenr(), 2)
end

test.mock.buf_set_name = function()
    local mock = Mock.new()
    test.equal(mock.bufs[1].name, "")
    mock.bufs[1].name = "test"
    test.equal(mock.bufs[1].name, "test")
end

test.mock.buf_set_lines = function()
    local mock = Mock.new()

    mock:buf_set_lines(mock:bufnr(), {
        "+ subdir-1",
        "+ subdir-2",
        "+ subdir-3",
        "  afile-1",
        "  bfile-2",
    })

    local lines = mock.bufs[mock:bufnr()].lines
    test.equal(lines[1], "+ subdir-1")
    test.equal(lines[2], "+ subdir-2")
    test.equal(lines[3], "+ subdir-3")
    test.equal(lines[4], "  afile-1")
    test.equal(lines[5], "  bfile-2")
end

test.mock.buf_insert_lines = function()
    local mock = Mock.new()

    mock:buf_set_lines(mock:bufnr(), {
        "+ subdir-1",
        "+ subdir-2",
        "+ subdir-3",
        "  afile-1",
        "  bfile-2",
    })
    mock:buf_insert_lines(mock:bufnr(), 4, {
        "  + subdir-3-1",
        "    file-3-1",
        "    file-3-2",
    })

    local lines = mock.bufs[mock:bufnr()].lines
    test.equal(lines[1], "+ subdir-1")
    test.equal(lines[2], "+ subdir-2")
    test.equal(lines[3], "+ subdir-3")
    test.equal(lines[4], "  + subdir-3-1")
    test.equal(lines[5], "    file-3-1")
    test.equal(lines[6], "    file-3-2")
    test.equal(lines[7], "  afile-1")
    test.equal(lines[8], "  bfile-2")
end

test.mock.buf_remove_lines = function()
    local mock = Mock.new()

    mock:buf_set_lines(mock:bufnr(), {
        "+ subdir-1",
        "+ subdir-2",
        "+ subdir-3",
        "  afile-1",
        "  bfile-2",
    })
    mock:buf_insert_lines(mock:bufnr(), 4, {
        "  + subdir-3-1",
        "    file-3-1",
        "    file-3-2",
    })
    mock:buf_remove_lines(mock:bufnr(), 4, 3)

    local lines = mock.bufs[mock:bufnr()].lines
    test.equal(lines[1], "+ subdir-1")
    test.equal(lines[2], "+ subdir-2")
    test.equal(lines[3], "+ subdir-3")
    test.equal(lines[4], "  afile-1")
    test.equal(lines[5], "  bfile-2")
end


test.open = function()
    -- local plugin = new()
    -- local vim = plugin.api

    -- plugin.open()

    -- test.equal(vim.bufs[vim.bufnr].lines[1], "+ subdir-1")
    -- test.equal(vim.bufs[vim.bufnr].lines[2], "+ subdir-2")
    -- test.equal(vim.bufs[vim.bufnr].lines[3], "+ subdir-3")
    -- test.equal(vim.bufs[vim.bufnr].lines[4], "  afile-1")
    -- test.equal(vim.bufs[vim.bufnr].lines[5], "  bfile-2")
end

-- test.insert.middle = function()
--     local a = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
--     local b = {[1] = "x", [2] = "y"}
--     fstree.insert(a, b, 3)

--     test.equal(a[1], "a")
--     test.equal(a[2], "b")
--     test.equal(a[3], "c")
--     test.equal(a[4], "x")
--     test.equal(a[5], "y")
--     test.equal(a[6], "d")
-- end

-- test.insert.atend = function()
--     local a = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
--     local b = {[1] = "x", [2] = "y"}
--     fstree.insert(a, b, 4)

--     test.equal(a[1], "a")
--     test.equal(a[2], "b")
--     test.equal(a[3], "c")
--     test.equal(a[4], "d")
--     test.equal(a[5], "x")
--     test.equal(a[6], "y")
-- end

-- test.insert.atbegin = function()
--     local a = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
--     local b = {[1] = "x", [2] = "y"}
--     fstree.insert(a, b, 1)

--     test.equal(a[1], "a")
--     test.equal(a[2], "x")
--     test.equal(a[3], "y")
--     test.equal(a[4], "b")
--     test.equal(a[5], "c")
--     test.equal(a[6], "d")
-- end

-- test.insert.empty = function()
--     local a = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
--     local b = {}
--     fstree.insert(a, b, 1)

--     test.equal(a[1], "a")
--     test.equal(a[2], "b")
--     test.equal(a[3], "c")
--     test.equal(a[4], "d")
-- end

-- test.join_level = function()
--     test.equal(fstree.join_level("/some/path", "tail"), "/some/path/tail")
--     test.equal(fstree.join_level("/some/path/", "tail"), "/some/path/tail")
-- end

-- test.trim_level = function()
--     test.equal(fstree.trim_level("/some/path/tail"), "/some/path")
--     test.equal(fstree.trim_level("/some/path/tail/"), "/some/path")
--     test.equal(fstree.trim_level("/some"), "/")
-- end

-- local CWD = "/tmp/test/fstree"

-- local function setup()
--     io.popen(string.format("mkdir -p %s/subdir-1", CWD)):close()
--     io.popen(string.format("mkdir -p %s/subdir-2", CWD)):close()
--     io.popen(string.format("mkdir -p %s/subdir-3", CWD)):close()
--     io.popen(string.format("mkdir -p %s/subdir-1/subdir-1-1", CWD)):close()
--     io.popen(string.format("mkdir -p %s/subdir-1/subdir-1-2", CWD)):close()
--     io.popen(string.format("mkdir -p %s/subdir-3/subdir-3-1", CWD)):close()
--     io.popen(string.format("echo file-1 > %s/afile-1", CWD)):close()
--     io.popen(string.format("echo file-2 > %s/bfile-2", CWD)):close()
--     io.popen(string.format("echo file-1-1 > %s/subdir-1/afile-1-1", CWD)):close()
--     io.popen(string.format("echo file-1-2 > %s/subdir-1/afile-1-2", CWD)):close()
--     io.popen(string.format("echo file-1-1-1 > %s/subdir-1/subdir-1-1/afile-1-1-1", CWD)):close()
--     io.popen(string.format("echo file-1-1-2 > %s/subdir-1/subdir-1-1/afile-1-1-2", CWD)):close()
--     io.popen(string.format("echo file-1-1-3 > %s/subdir-1/subdir-1-1/afile-1-1-3", CWD)):close()
--     io.popen(string.format("echo file-1-2-1 > %s/subdir-1/subdir-1-2/afile-1-2-1", CWD)):close()
--     io.popen(string.format("echo file-1-2-2 > %s/subdir-1/subdir-1-2/afile-1-2-2", CWD)):close()
--     io.popen(string.format("echo file-2-1 > %s/subdir-2/zfile-2-1", CWD)):close()
--     io.popen(string.format("echo file-2-2 > %s/subdir-2/zfile-2-2", CWD)):close()
--     io.popen(string.format("echo file-2-3 > %s/subdir-2/bfile-2-3", CWD)):close()
-- end

-- local function teardown()
--     io.popen(string.format("rm -rf %s", CWD))
-- end

-- test.start_up = setup
-- test.tear_down = teardown

-- function nvimmock()
--     local vars = {
--         fstree_indent_size = 2,
--         fstree_char_dirclos = "+",
--         fstree_char_diropen = "-",
--         fstree_exclude = {"^%.$", "^%..$"}
--     }

--     local bufs = {
--         [1] = {
--             lines = {}
--         },
--         name = "",
--     }
--     local curbuf = 1

--     local this = {
--         bufs = bufs,

--         nvim_get_var = function(name)
--             return vars[name]
--         end,

--         nvim_buf_set_lines = function(bufnr, a, b, strict, lines)
--             for i = a, b do
--                 bufs[bufnr].lines[i] = lines[i]
--             end
--         end,

--         nvim_buf_set_name = function(bufnr, name)
--             bufs[bufnr].name = name
--         end,

--         nvim_get_current_buf = function()
--             return curbuf
--         end
--     }

--     return this
-- end

-- test.scan = function()
--     -- local filter = fstree.filter({"^%.$", "^%..$"})
--     -- local expand = {
--     --     ["subdir-1"] = true,
--     --     ["subdir-3"] = true,
--     --     ["subdir-1-1"] = true,
--     --     ["subdir-1-2"] = true,
--     -- }
--     -- local tree = fstree.scan(prefix, expand, filter, 0)

--     -- test.equal(tree.entries[1].name, "subdir-1")
--     -- test.equal(tree.entries[2].name, "subdir-1-1")
--     -- test.equal(tree.entries[3].name, "afile-1-1-1")
--     -- test.equal(tree.entries[4].name, "afile-1-1-2")
--     -- test.equal(tree.entries[5].name, "afile-1-1-3")
--     -- test.equal(tree.entries[6].name, "subdir-1-2")
--     -- test.equal(tree.entries[7].name, "afile-1-2-1")
--     -- test.equal(tree.entries[8].name, "afile-1-2-2")
--     -- test.equal(tree.entries[9].name, "afile-1-1")
--     -- test.equal(tree.entries[10].name, "afile-1-2")
--     -- test.equal(tree.entries[11].name, "subdir-2")
--     -- test.equal(tree.entries[12].name, "subdir-3")
--     -- test.equal(tree.entries[14].name, "afile-1")
--     -- test.equal(tree.entries[15].name, "bfile-2")
-- end

-- test.mock.nvim_get_var = function()
--     local mock = nvimmock()
--     test.equal(mock.nvim_get_var("fstree_indent_size"), 2)
--     test.equal(mock.nvim_get_var("fstree_char_dirclos"), "+")
--     test.equal(mock.nvim_get_var("fstree_char_diropen"), "-")
--     test.equal(mock.nvim_get_var("fstree_exclude")[1], "^%.$")
--     test.equal(mock.nvim_get_var("fstree_exclude")[2], "^%..$")
-- end

-- test.controller.start_up = setup
-- test.controller.tear_down = teardown

-- test.controller.open = function()
--     local mock = nvimmock()
--     local controller = fstree.Controller.new(mock, CWD)

--     controller:open(0)

--     local buf = mock.bufs[mock.nvim_get_current_buf()]
--     test.equal(buf.name, "")
--     test.equal(buf.lines[1], "+ subdir-1")
--     test.equal(buf.lines[2], "+ subdir-2")
--     test.equal(buf.lines[3], "+ subdir-3")
--     test.equal(buf.lines[4], "  afile-1")
--     test.equal(buf.lines[5], "  bfile-2")

--     controller:open(1)

--     local buf = mock.bufs[mock.nvim_get_current_buf()]
--     test.equal(buf.name, "subdir-1")
--     test.equal(buf.lines[1], "+ subdir-1-1")
--     test.equal(buf.lines[2], "+ subdir-1-2")
--     test.equal(buf.lines[3], "  afile-1-1")
--     test.equal(buf.lines[4], "  afile-1-2")
-- end

-- test.controller.back = function()
--     local mock = nvimmock()
--     local controller = fstree.Controller.new(mock, CWD)

--     controller:open(0)
--     controller:open(1)
--     controller:back()

--     local buf = mock.bufs[mock.nvim_get_current_buf()]
--     test.equal(buf.name, "")
--     test.equal(buf.lines[1], "+ subdir-1")
--     test.equal(buf.lines[2], "+ subdir-2")
--     test.equal(buf.lines[3], "+ subdir-3")
--     test.equal(buf.lines[4], "  afile-1")
--     test.equal(buf.lines[5], "  bfile-2")
-- end

-- -- test.model.expand = function()
-- -- end

-- -- test.model.collapse = function()
-- -- end

-- test.summary()
