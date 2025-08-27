package.path = package.path .. ";./spec/support/?.lua"
local helpers = require('spec.support.test_helpers')
local mime = require('mime')

describe('bookdrop/http_server download edge cases', function()
    local fake_settings = {
        stored = { Upload_parms = { username = 'admin', password = 'secret' }, home_dir = '/home/koreader' },
        readSetting = function(self, k)
            if k == 'Upload_parms' then return self.stored.Upload_parms end
            if k == 'home_dir' then return self.stored.home_dir end
            return nil
        end
    }

    it('serves empty file (0 bytes) correctly', function()
        local file_path = '/home/koreader/empty.txt'
        local file_contents = ''

        local lfs_mock = {
            dir = function() return function() return nil end end,
            attributes = function(path, attr)
                if path == file_path then
                    return { mode = 'file', modification = 1620000000 }
                end
                return nil
            end
        }

        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)

        local io_helper = require('spec.support.io')
        local esc = require('spec.support.socket.url').escape(file_path)
        local resp
        io_helper.with_io_open_mock({ [file_path] = function(mode)
            if mode == 'rb' then
                return { read = function(_, what) if what == '*all' then return file_contents end end, close = function() end }
            end
            return nil
        end }, function()
            resp = helpers.run_server_with_client({"GET /download?file=" .. esc .. " HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1, injected_modules = { ['libs/libkoreader-lfs'] = lfs_mock } })
        end)

        assert.is_true(resp:match('HTTP/1.1 200 OK') ~= nil)
        assert.is_true(resp:match('Content%-Length:%s*0') ~= nil)
        local body = resp:match('\r\n\r\n(.*)$') or ''
        assert.are.equal('', body)
    end)

    it('returns 404 when file exists but cannot be opened (permission)', function()
        local file_path = '/home/koreader/protected.txt'
        local lfs_mock = {
            dir = function() return function() return nil end end,
            attributes = function(path, attr)
                if path == file_path then
                    return { mode = 'file', modification = 1620000000 }
                end
                return nil
            end
        }

        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)

        local io_helper = require('spec.support.io')
        local esc = require('spec.support.socket.url').escape(file_path)
        local resp
        io_helper.with_io_open_mock({ [file_path] = function(mode) return nil end }, function()
            resp = helpers.run_server_with_client({"GET /download?file=" .. esc .. " HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1, injected_modules = { ['libs/libkoreader-lfs'] = lfs_mock } })
        end)

        assert.is_true(resp:match('HTTP/1.1 404 Not Found') ~= nil)
        assert.is_true(resp:match('could not be opened for reading') ~= nil)
    end)

    it('handles filenames with spaces and unicode', function()
        local file_path = '/home/koreader/My Book – 漢字.pdf'
        local file_contents = 'PDFBYTES'
        local lfs_mock = {
            dir = function() return function() return nil end end,
            attributes = function(path, attr)
                if path == file_path then
                    return { mode = 'file', modification = 1620000000 }
                end
                return nil
            end
        }
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)
        local io_helper = require('spec.support.io')
        local esc = require('spec.support.socket.url').escape(file_path)
        local resp
        io_helper.with_io_open_mock({ [file_path] = function(mode)
            if mode == 'rb' then
                return { read = function(_, what) if what == '*all' then return file_contents end end, close = function() end }
            end
            return nil
        end }, function()
            resp = helpers.run_server_with_client({"GET /download?file=" .. esc .. " HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1, injected_modules = { ['libs/libkoreader-lfs'] = lfs_mock } })
        end)

        assert.is_true(resp:match('HTTP/1.1 200 OK') ~= nil)
        assert.is_true(resp:find('Content-Disposition: attachment; filename=My Book – 漢字.pdf', 1, true) ~= nil)
        local body = resp:match('\r\n\r\n(.*)$')
        assert.are.equal(file_contents, body)
    end)

    it('omits Last-Modified header when modification not provided', function()
        local file_path = '/home/koreader/no_mtime.txt'
        local file_contents = 'data'
        local lfs_mock = {
            dir = function() return function() return nil end end,
            attributes = function(path, attr)
                if path == file_path then
                    return { mode = 'file' } -- no modification
                end
                return nil
            end
        }
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)
        local io_helper = require('spec.support.io')
        local esc = require('spec.support.socket.url').escape(file_path)
        local resp
        io_helper.with_io_open_mock({ [file_path] = function(mode)
            if mode == 'rb' then
                return { read = function(_, what) if what == '*all' then return file_contents end end, close = function() end }
            end
            return nil
        end }, function()
            resp = helpers.run_server_with_client({"GET /download?file=" .. esc .. " HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1, injected_modules = { ['libs/libkoreader-lfs'] = lfs_mock } })
        end)

        assert.is_true(resp:match('HTTP/1.1 200 OK') ~= nil)
        assert.is_true(resp:find('Last-Modified:', 1, true) == nil)
    end)
end)
