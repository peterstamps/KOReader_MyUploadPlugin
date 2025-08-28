package.path = package.path .. ";./spec/support/?.lua"
local lfs_mock = require('spec.support.libkoreader-lfs')
local mime = require('mime')
local helpers = require('spec.support.test_helpers')

describe('bookdrop/http_server negative cases', function()
    local fake_settings
    setup(function()
        fake_settings = {
            stored = { Upload_parms = { username = 'admin', password = 'secret' }, home_dir = '/home/koreader' },
            readSetting = function(self, k)
                if k == 'Upload_parms' then return self.stored.Upload_parms end
                if k == 'home_dir' then return self.stored.home_dir end
                if k == 'exporter' then return nil end
                return nil
            end
        }
    end)

    it('returns 401 on POST /login with wrong credentials', function()
        local body = 'username=bad&password=wrong'
        local resp = helpers.run_server_with_client({"POST /login HTTP/1.1", "content-length: " .. tostring(#body), "", body}, { fake_settings = fake_settings, seconds_runtime = 1 })
        assert.is_true(resp:match('HTTP/1.1 401 Unauthorized') ~= nil)
        assert.is_true(resp:match('No access to the Upload server') ~= nil)
    end)

    it('returns 400 on POST /upload when Content-Type missing boundary', function()
        -- Provide valid auth cookie
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)
        -- Build POST /upload with content-type lacking boundary
    local resp = helpers.run_server_with_client({"POST /upload HTTP/1.1", "content-type: multipart/form-data", "cookie: " .. cookie, "", ""}, { fake_settings = fake_settings, seconds_runtime = 1 })
    assert.is_true(resp:match('HTTP/1.1 400 Bad Request') ~= nil)
    assert.is_true(resp:match('Missing boundary in Content%-Type') ~= nil)
    end)

    it('returns 404 on GET /download for nonexistent file', function()
        -- Ensure lfs reports no such file
        lfs_mock._set_fs({ ['/home/koreader'] = {} })
        package.loaded['libs/libkoreader-lfs'] = lfs_mock
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)
    local resp = helpers.run_server_with_client({"GET /download?file=/home/koreader/nope.txt HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1, injected_modules = { ['libs/libkoreader-lfs'] = lfs_mock } })
    assert.is_true(resp:match('HTTP/1.1 404 Not Found') ~= nil)
    assert.is_true(resp:match('File not found') ~= nil)
    end)

    it('redirects to /login when UploadsAuthorized cookie is malformed', function()
    local resp = helpers.run_server_with_client({"GET /files HTTP/1.1", "cookie: UploadsAuthorized=not-base64!!!", "", nil}, { fake_settings = fake_settings, seconds_runtime = 1 })
    assert.is_true(resp:match('Location:%s*/login') ~= nil)
    end)

    it('returns 400 when download file parameter is empty', function()
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)
    local resp = helpers.run_server_with_client({"GET /download?file= HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1 })
    assert.is_true(resp:match('HTTP/1.1 400 Bad Request') ~= nil)
    assert.is_true(resp:match('Invalid file request') ~= nil)
    end)

    it('clears cookie and redirects on GET /logout when authorized', function()
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)
    local resp = helpers.run_server_with_client({"GET /logout HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1 })
    assert.is_true(resp:match('Location:%s*/login%?loggedout=1') ~= nil)
    assert.is_true(resp:find('Set-Cookie: UploadsAuthorized=;expires=Thu, 01 Jan 1970 00:00:00 GMT;', 1, true) ~= nil)
    end)
end)
