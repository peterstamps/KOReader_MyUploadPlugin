local M = {}

function M.unescape(s)
    if not s then return s end
    s = s:gsub('+', ' ')
    s = s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h,16)) end)
    return s
end

return M
