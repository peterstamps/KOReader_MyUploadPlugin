local lfs = require("libs/libkoreader-lfs")
local io = require("io")
local url = require("socket.url")

local M = {}

function M.is_dir(path)
    local ok, mode = pcall(function() return lfs.attributes(path, "mode") end)
    return ok and mode == "directory"
end

function M.list_files(dir)
    if string.len(dir) == 0 then dir = '.' end
    local files = {}
    for file in lfs.dir(dir) do
        local full_path = dir .. "/" .. file
        if file ~= "." and file ~= ".." then
            if lfs.attributes(full_path, "mode") == "file" then
                table.insert(files, file)
            end
        end
    end
    return files
end

function M.list_folders(dir, extMatch)
    local function recurse_dir(d)
        local folders = {}
        for file in lfs.dir(d) do
            local full_path = d .. "/" .. file
            if file ~= "." and file ~= ".." then
                local mode = lfs.attributes(full_path, "mode")
                if mode == "directory" then
                    table.insert(folders, full_path)
                    local subfolders = recurse_dir(full_path)
                    for _, subfolder in ipairs(subfolders) do
                        table.insert(folders, subfolder)
                    end
                else
                    if extMatch and extMatch(full_path) then
                        table.insert(folders, full_path)
                    end
                end
            end
        end
        return folders
    end
    return recurse_dir(dir)
end

function M.save_file(file_data, filename, upload_dir)
    if filename and file_data and type(file_data) == "string" then
        local file_path = upload_dir .. "/" .. filename
        file_path = url.unescape(file_path)
        local file, err = io.open(file_path, "wb")
        if not file then
            print("Error opening file for writing: " .. err)
            return false
        end
        file:write(file_data)
        file:close()
        return true
    else
        return false
    end
end

return M
