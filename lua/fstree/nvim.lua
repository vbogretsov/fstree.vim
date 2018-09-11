--- nvim: provides interface for neovim interaction

local Nvim = {}
Nvim.__index = Nvim

function Nvim.new()
    local self = setmetatable({}, Nvim)
    self.api = vim.api
    return self
end

function Nvim:linenr()
    return self.api.nvim_eval("line('.')")
end

function Nvim:bufnr()
    return self.api.nvim_get_current_buf()
end

function Nvim:buf_set_name(name)
    self.api.nvim_buf_set_name(name)
end

function Nvim:buf_set_lines(bufnr, lines)
    local num_lines = self.api.nvim_buf_line_count()

    self.api.nvim_buf_set_lines(buf, 0, num_lines, false, {})
    self.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
end

function Nvim:buf_insert_lines(bufnr, pos, lines)
    self.api.nvim_buf_set_lines(buf, pos, pos, false, lines)
end

function Nvim:buf_remove_lines(bufnr, pos, len)
    self.api.nvim_buf_set_lines(buf, pos, pos + len, false, {})
end

function Nvim:get_var(name)
    return self.api.nvim_get_var(name)
end
