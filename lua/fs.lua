--- FFI based file system library
---
local ffi = require("ffi")


local OS = ffi.os

if OS == "Windows" then
    error("Windows is not supported now")
end

local _M = {
    _VERSION = "0.1.0",
}

local DIR_MODE = 509
local SEP = "/"

_M.TYPE = {
    DIR = 1,
    REG = 2,
    LNK = 3,
}

--- Standard library functions
---
ffi.cdef[[
    char* strerror(int errnum);
    void *fopen(const char *path, const char *mode);
    int fclose(void *fp);
    int remove(const char *path);
    int rename(const char *src, const char *dst);
]]

--- OS specific POSIX direct declaration
---
if OS == 'OSX' or OS == 'BSD' then
    -- NOTE: don't know how to use externally defined constants in ffi.cdef.
    ffi.cdef[[
        enum uint8_t {
            DT_DIR = 4,
            DT_REG = 8,
            DT_LNK = 10
        };

        struct dirent {
            uint32_t d_ino;
            uint16_t d_reclen;
            uint8_t  d_type;
            uint8_t  d_namlen;
            char     d_name[256];
        };
    ]]
else
    -- NOTE: don't know how to use externally defined constants in ffi.cdef.
    -- TODO: ensure constants have correcct values.
    ffi.cdef[[
        enum uint8_t {
            DT_DIR = 4,
            DT_REG = 8,
            DT_LNK = 10
        };

        struct dirent {
            int64_t        d_ino;
            size_t         d_off;
            unsigned short d_reclen;
            unsigned char  d_type;
            char           d_name[256];
        };
    ]]
end


local DT2TYPE = {
    [ffi.C.DT_DIR] = _M.TYPE.DIR,
    [ffi.C.DT_REG] = _M.TYPE.REG,
    [ffi.C.DT_LNK] = _M.TYPE.LNK,
}

--- POSIX functions
---
ffi.cdef[[
    int rmdir(const char *path);
    int mkdir(const char *path, unsigned int mode);
    typedef struct  __dirstream DIR;
    DIR *opendir(const char *name);
    struct dirent *readdir(DIR *dirp);
    int closedir(DIR *dirp);
]]


local function fatal()
    error(ffi.string(ffi.C.strerror(ffi.errno())))
end


function string:split(sep)
    local sep, fields = sep, {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

--- List all entries in the directory. Not recursive.
-- @param  path string -- directory path
-- @return directory entries iterator
function _M.lsdir(path)
    local dir = ffi.C.opendir(path)
    if dir == nil then
        fatal()
    end

    local function iter()
        local entry = ffi.C.readdir(dir)
        if entry ~= nil then
            local name = ffi.string(entry.d_name)
            if name == "." or name == ".." then
                return iter()
            else
                return {name = name, type = DT2TYPE[entry.d_type]}
            end
        else
            ffi.C.closedir(dir)
            dir = nil
            return nil
        end
    end

    return iter
end

--- Create new directory with the permissions drwx r-x r-x.
-- @param   path string -- directory path
function _M.mkdir(path)
    local err = ffi.C.mkdir(path, DIR_MODE);
    if err ~= 0 then
        fatal()
    end
end


--- Remove directory and its content recursive.
-- @param   path strin -- directory path
function _M.rmdir(path)
    for i in _M.lsdir(path) do
        local p = _M.join(path, i.name)
        if i.type == _M.TYPE.DIR then
            _M.rmdir(p)
        else
            _M.rm(p)
        end
    end

    local err = ffi.C.rmdir(path)
    if err ~= 0 then
        fatal()
    end
end


--- Create new file.
-- @param   path string -- file path
function _M.creat(path)
    local fp = ffi.C.fopen(path, "w");
    if fp == nil then
        fatal()
    end
    ffi.C.fclose(fp)
end


--- Remove file.
-- @param   path string  file path
function _M.rm(path)
    local err = ffi.C.remove(path)
    if err ~= 0 then
        fatal()
    end
end


--- Rename directory or file.
-- @param   src string -- old name
-- @param   dst string -- new name
function _M.mv(src, dst)
    local err = ffi.C.rename(src, dst)
    if err ~=0 then
        fatal()
    end
end


--- Join path components.
-- @param    ... -- parh components
function _M.join(...)
    local t = {...}

    local parts = {}
    for i = 1, #t do
        for _, s in pairs(t[i]:split(SEP)) do
            if s == ".." then
                table.remove(parts, #parts)
            else
                table.insert(parts, s)
            end
        end
    end

    local path = table.concat(parts, SEP)
    local prefix = string.sub(t[1], 1, 1) == SEP and SEP or ""

    return string.format("%s%s", prefix, path)
end

return _M