local fs = require("fs")


local _M = {}

--- Sefines sorting order of directory items where directories are always on
-- top and all items ordered alphabetically.
-- @param  a table: left value
-- @param  b table: right value
-- @return bool: true if a < b, otherwise false
function _M.dirontop(a, b)
    if a.type == fs.TYPE.DIR then
        if b.type == fs.TYPE.DIR then
            return a.name < b.name
        else
            return true
        end
    else
        if b.type == fs.TYPE.DIR then
            return false
        else
            return a.name < b.name
        end
    end
end

return _M