package.path = package.path .. ";./spec/support/?.lua"
local support = require('spec.support.init')
local mime = require('mime')
local helpers = require('spec.support.test_helpers')

describe('bookdrop/http_server', function()
    local fake_settings
    setup(function()
        fake_settings = {
            stored = { Upload_parms = { username = 'admin', password = 'secret' }, home_dir = '/tmp' },
            readSetting = function(self, k)
                if k == 'Upload_parms' then return self.stored.Upload_parms end
                if k == 'home_dir' then return self.stored.home_dir end
                if k == 'exporter' then return nil end
                return nil
            end
        }
    end)

    it('serves login page on GET /', function()
        local resp = helpers.run_server_with_client({"GET / HTTP/1.1", "", nil}, { fake_settings = fake_settings, seconds_runtime = 1 })
    assert.is_not_nil(resp)
    assert.is_true(resp:match("HTTP/1.1 200 OK") ~= nil)
    assert.is_true(resp:match("Content%-Type:%s*text/html") ~= nil)
    assert.is_true(resp:match("<title>BookDrop Login</title>") ~= nil)
    -- form and inputs
    assert.is_true(resp:find('<form action="/login" method="POST"', 1, true) ~= nil)
    assert.is_true(resp:find('name="username"', 1, true) ~= nil)
    assert.is_true(resp:find('name="password"', 1, true) ~= nil)
    end)

    it('redirects on successful login (POST /login)', function()
        local body = 'username=admin&password=secret'
        local resp = helpers.run_server_with_client({"POST /login HTTP/1.1", "content-length: " .. tostring(#body), "", body}, { fake_settings = fake_settings, seconds_runtime = 1 })

    assert.is_not_nil(resp)
    assert.is_true(resp:match("HTTP/1.1 302 Found") ~= nil)
    assert.is_true(resp:match("Location:%s*/upload") ~= nil)
    local expected_cookie = "UploadsAuthorized=" .. mime.b64("admin:secret")
    -- send_response_location appends a trailing semicolon to Set-Cookie
    assert.is_true(resp:find("Set-Cookie: " .. expected_cookie .. ";", 1, true) ~= nil)
    end)

    it('redirects to /login when GET /upload unauthenticated', function()
        local resp = helpers.run_server_with_client({"GET /upload HTTP/1.1", "", nil}, { fake_settings = fake_settings, seconds_runtime = 1 })
        assert.is_not_nil(resp)
        assert.is_true(resp:match("HTTP/1.1 302 Found") ~= nil)
        assert.is_true(resp:match("Location:%s*/login") ~= nil)
    end)

    it('serves upload form when authenticated (GET /upload)', function()
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)
        local resp = helpers.run_server_with_client({"GET /upload HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1 })
        assert.is_not_nil(resp)
        assert.is_true(resp:match("HTTP/1.1 200 OK") ~= nil)
        assert.is_true(resp:find('<form action="/upload"', 1, true) ~= nil)
    end)

    it('redirects POST /upload to /login when unauthenticated', function()
        local body = ''
        local resp = helpers.run_server_with_client({"POST /upload HTTP/1.1", "content-type: multipart/form-data; boundary=X", "", body}, { fake_settings = fake_settings, seconds_runtime = 1 })
        assert.is_not_nil(resp)
        assert.is_true(resp:match("HTTP/1.1 302 Found") ~= nil)
        assert.is_true(resp:match("Location:%s*/login") ~= nil)
    end)
end)
