package.path = package.path .. ";./spec/support/?.lua"
local helpers = require('spec.support.test_helpers')
local mime = require('mime')

describe('bookdrop/http_server download', function()
    it('serves file bytes with correct headers on GET /download', function()
        local fake_settings = {
            stored = { Upload_parms = { username = 'admin', password = 'secret' }, home_dir = '/home/koreader' },
            readSetting = function(self, k)
                if k == 'Upload_parms' then return self.stored.Upload_parms end
                if k == 'home_dir' then return self.stored.home_dir end
                return nil
            end
        }

        local file_path = '/home/koreader/readme.txt'
        local file_contents = 'Hello BookDrop\n'

        -- LFS mock that reports the file exists and has a modification time
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

        assert.is_not_nil(resp)
        assert.is_true(resp:match('HTTP/1.1 200 OK') ~= nil)
        assert.is_true(resp:match('Content%-Length:%s*' .. tostring(#file_contents)) ~= nil)
        assert.is_true(resp:find('Content-Disposition: attachment; filename=readme.txt', 1, true) ~= nil)
        assert.is_true(resp:find('Last-Modified: ', 1, true) ~= nil)
        local body = resp:match('\r\n\r\n(.*)$')
        assert.are.equal(file_contents, body)
    end)
end)
