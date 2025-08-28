package.path = package.path .. ";./spec/support/?.lua"
local lfs_mock = require('spec.support.libkoreader-lfs')
local mime = require('mime')
local helpers = require('spec.support.test_helpers')


describe('bookdrop/http_server - /files', function()
    local fake_settings
    setup(function()
        fake_settings = {
            stored = { Upload_parms = { username = 'admin', password = 'secret' }, home_dir = '/home/koreader' },
            readSetting = function(self, k)
                if k == 'Upload_parms' then return self.stored.Upload_parms end
                if k == 'home_dir' then return self.stored.home_dir end
                return nil
            end
        }
    end)

    it('redirects to /login when unauthorized', function()
        local resp = helpers.run_server_with_client({"GET /files HTTP/1.1", "", nil}, { fake_settings = fake_settings, seconds_runtime = 1 })
        assert.is_true(resp:match('Location:%s*/login') ~= nil)
    end)

    it('lists folders and files when authorized', function()
        -- Setup fake fs: home dir contains folder 'Books' and file 'readme.txt'
        lfs_mock._set_fs({ ['/home/koreader'] = {'Books','readme.txt'}, ['/home/koreader/Books'] = {'book1.epub'} })
        -- Ensure http_server will use our lfs mock
        package.loaded['libs/libkoreader-lfs'] = lfs_mock
        local creds = 'admin:secret'
        local cookie = 'cookie=1; UploadsAuthorized=' .. mime.b64(creds) .. '; other=2'
        -- Request: GET /files with cookie header
    local resp = helpers.run_server_with_client({"GET /files HTTP/1.1", "cookie: " .. cookie, "", nil}, { fake_settings = fake_settings, seconds_runtime = 1, injected_modules = { ['libs/libkoreader-lfs'] = lfs_mock } })

    assert.is_true(resp:match('<table') ~= nil)
    -- Breadcrumb should link to escaped home dir
    local esc_home = require('spec.support.socket.url').escape('/home/koreader')
    assert.is_true(resp:find('/files?dir=' .. esc_home, 1, true) ~= nil)
    -- Exact entries
    assert.is_true(resp:find('>Books<', 1, true) ~= nil)
    assert.is_true(resp:find('>readme.txt<', 1, true) ~= nil)
    end)
end)
