local M = {}

-- Minimal mock of lfs used by file_utils tests.
local fs = {}

function M.dir(path)
    local i = 0
    local list = fs[path] or {}
    return function()
        i = i + 1
        return list[i]
    end
end

function M.attributes(path, attr)
    if attr ~= "mode" then return nil end
    if fs[path] then
        return "directory"
    else
        for dir, list in pairs(fs) do
            for _, name in ipairs(list) do
                if dir .. "/" .. name == path then return "file" end
            end
        end
    end
    return nil
end

function M._set_fs(table)
    fs = table or {}
end

return M
