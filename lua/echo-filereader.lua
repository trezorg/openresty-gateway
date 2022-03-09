local _M = { _VERSION = '0.0.1' }

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local content = file:read "*all"
    file:close()
    return content
end

_M.read_file = read_file

return _M