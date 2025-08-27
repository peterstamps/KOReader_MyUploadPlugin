local M = {}

-- Minimal mock of lfs used by file_utils tests.
local fs = {}

function M.dir(path)
    -- Return iterator over files in fs[path] which is a table of names
    local i = 0
    local list = fs[path] or {}
    return function()
        i = i + 1
        return list[i]
    end
end

function M.attributes(path, attr)
    -- path may be a directory or file
    if attr ~= "mode" then return nil end
    if fs[path] then
        return "directory"
    else
        -- if any dir contains the filename, it's a file
        for dir, list in pairs(fs) do
            for _, name in ipairs(list) do
                if dir .. "/" .. name == path then return "file" end
            end
        end
    end
    return nil
end

-- Expose helper to tests to set mock filesystem
function M._set_fs(table)
    fs = table or {}
end

return M
