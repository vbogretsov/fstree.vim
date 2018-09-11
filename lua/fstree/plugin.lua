--- plugin: provides plugin controller
fs = require("posixfs")

local VAR_INDENT_SIZE = "fstree_indent_size"
local VAR_CHAR_DIRCLOS = "fstree_char_dirclos"
local VAR_CHAR_DIROPEN = "fstree_char_diropen"

function formatter(api, expanded)
    indent = api.nvim_get_var(VAR_INDENT_SIZE)

    signs = {
        [VAR_CHAR_DIRCLOS] = api:get_var(VAR_CHAR_DIRCLOS),
        [VAR_CHAR_DIROPEN] = api:get_var(VAR_CHAR_DIROPEN),
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
            local indentation = string.rep(" ", indent * e.level)
            lines[#lines + 1] = indentation .. fmt[e.type](e)
        end
        return lines
    end
end

local function open_dir(dir, api, model)
    model:open(dir)

    local bufnr = api:bufnr()
    local format = formatter(api, model.expanded)

    api:buf_set_lines(bufnr, format(model.entries))
    api:buf_set_name(bufnr, model.cwd)
end

local function open_file(file, api, model)
end

--- represents plugin controller, implements all plugin operations
local Plugin = {}
Plugin.__index = {}

function Plugin.new(api, model)
    local self = setmetatable({}, Plugin)
    self.api = api
    self.model = model
    return self
end

function Plugin:open()
    open_dir("", self.api, self.model)
end

function Plugin:next()
    local entry = self.model.entries[self.api:linenr()]
    if entry.type == fs.FSITEM_DIR then
        open_dir(entry.name, self.api, self.model)
    else
        open_file(entry.name, self.api, self.model)
    end
end

function Plugin:back()
    open_dir("..", self.api, self.model)
end

function Plugin:expand()
    local pos = self.api:linenr()
    local entry = self.model.entries[pos]
    if entry.type ~= fs.FSITEM_DIR then
        return
    end
    local lines = format(self.model.expand(entry))
    self.api:buf_insert_lines(self.api:bufnr(), pos, lines)
    -- TODO: change folder sign
end

function Plugin:expand_all()
end

function Plugin:collapse()
    local entry = self.model.entries[self.api.linenr()]
    if entry.type ~= fs.FSITEM_DIR then
        entry = self.model:parent(entry)
    end
    local pos, len = self.model:collapse(entry)
    self.api:buf_remove_lines(self.api:bufnr(), ind, len)
    -- TODO: change folder sign
end

function Plugin:collapse_all()
end

function Pluging:locate()
end
