local M = {}

function M.unescape(s)
    if not s then return s end
    s = s:gsub('+', ' ')
    s = s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h,16)) end)
    return s
end

function M.escape(s)
    if not s then return s end
    return (s:gsub("([^%w%-%_%.~])", function(c) return string.format("%%%02X", string.byte(c)) end))
end

function M.parse(path)
    if not path then return { query = nil } end
    local q = path:match("%?(.*)")
    return { query = q }
end

return M
