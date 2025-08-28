-- ensure spec support is on package.path
package.path = package.path .. ";./spec/support/?.lua"

local file_utils = require("bookdrop/file_utils")
local lfs_mock = require("libs/libkoreader-lfs")

local tmp_dir = "spec/tmp"

describe("bookdrop/file_utils.lua", function()
    before_each(function()
        -- setup fake fs
        local fs = {}
        fs[tmp_dir] = {"file1.txt", "file2.pdf", "subdir"}
        fs[tmp_dir .. "/subdir"] = {"nested.epub"}
        lfs_mock._set_fs(fs)
        -- ensure tmp directory exists for save_file tests
        os.execute("mkdir -p " .. tmp_dir)
    end)

    after_each(function()
        -- cleanup tmp directory files created by save_file
        os.execute("rm -rf " .. tmp_dir)
    end)

    describe("is_dir", function()
        it("returns true for directories in mock fs", function()
            assert.is_true(file_utils.is_dir(tmp_dir))
            assert.is_true(file_utils.is_dir(tmp_dir .. "/subdir"))
        end)

        it("returns false for non-existent paths", function()
            assert.is_false(file_utils.is_dir(tmp_dir .. "/nope"))
        end)
    end)

    describe("list_files", function()
        it("lists only files (not . or ..)", function()
            local files = file_utils.list_files(tmp_dir)
            table.sort(files)
            assert.are.same({"file1.txt","file2.pdf"}, files)
        end)
    end)

    describe("list_folders", function()
        it("recursively lists folders and returns full paths", function()
            local folders = file_utils.list_folders(tmp_dir)
            table.sort(folders)
            assert.are.same({tmp_dir .. "/subdir"}, folders)
        end)

        it("returns matching files when extMatch provided", function()
            local function extMatch(path) return path:match("%.epub$") end
            local folders = file_utils.list_folders(tmp_dir, extMatch)
            table.sort(folders)
            assert.are.same({tmp_dir .. "/subdir", tmp_dir .. "/subdir/nested.epub"}, folders)
        end)
    end)

    describe("save_file", function()
        it("saves a file and returns true", function()
            local ok = file_utils.save_file("hello", "out.txt", tmp_dir)
            assert.is_true(ok)
            -- verify file exists
            local f = io.open(tmp_dir .. "/out.txt", "rb")
            assert.is_not_nil(f)
            local content = f:read("*a")
            f:close()
            assert.equals("hello", content)
        end)

        it("returns false for bad input", function()
            assert.is_false(file_utils.save_file(nil, "x", tmp_dir))
            assert.is_false(file_utils.save_file("data", nil, tmp_dir))
        end)
    end)
end)
