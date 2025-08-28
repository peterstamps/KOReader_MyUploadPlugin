package.path = package.path .. ";./spec/support/?.lua"
local helpers = require('spec.support.test_helpers')
local io_helper = require('spec.support.io')
local mime = require('mime')

local function push_chars(tbl, str)
    for c in str:gmatch('.') do table.insert(tbl, c) end
end

describe('bookdrop/http_server upload edge cases', function()
    local fake_settings = {
        stored = { Upload_parms = { username = 'admin', password = 'secret' }, home_dir = '/home/koreader' },
        readSetting = function(self, k)
            if k == 'Upload_parms' then return self.stored.Upload_parms end
            if k == 'home_dir' then return self.stored.home_dir end
            return nil
        end
    }

    it('handles truncated multipart upload (no terminating boundary)', function()
        local filename = 'truncated.txt'
        local file_path = fake_settings.stored.home_dir .. '/' .. filename
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)

        local seq = {}
        table.insert(seq, "POST /upload HTTP/1.1")
        table.insert(seq, "Content-Type: multipart/form-data; boundary=BOUNDARY")
        table.insert(seq, "cookie: " .. cookie)
        table.insert(seq, "")

        -- Build multipart preamble and two content lines, but omit terminating boundary
        push_chars(seq, "--BOUNDARY\r\n")
        push_chars(seq, 'Content-Disposition: form-data; name="file"; filename="' .. filename .. '"\r\n')
        push_chars(seq, "Content-Type: application/octet-stream\r\n")
        push_chars(seq, "\r\n")
        push_chars(seq, "LINE1\r\n")
        push_chars(seq, "LINE2\r\n")
        -- no terminating boundary; client will EOF

        local captured = ''
        local lfs_mock = { dir = function() return function() return nil end end, attributes = function() return { mode = 'file' } end }

        local resp
        io_helper.with_io_open_mock({ [file_path] = function(mode)
            if mode == 'wb' then
                return { write = function(_, data) captured = captured .. data end, close = function() end }
            end
            return nil
        end }, function()
            resp = helpers.run_server_with_client(seq, { fake_settings = fake_settings, seconds_runtime = 1, injected_modules = { ['libs/libkoreader-lfs'] = lfs_mock } })
        end)

    assert.is_not_nil(resp)
    assert.is_true(resp:match('HTTP/1.1 200 OK') ~= nil)
    -- Content-Type should be text/html; Content-Length should match body
    assert.is_true(resp:match('Content%-Type:%s*text/html') ~= nil)
    local cl = resp:match('Content%-Length:%s*(%d+);')
    assert.is_not_nil(cl)
    local body = resp:match('\r\n\r\n(.*)$') or ''
    assert.are.equal(tonumber(cl), #body)
    assert.is_true(resp:match('File uploaded successfully') ~= nil)
    assert.is_true(body:find(filename, 1, true) ~= nil)

        -- When truncated (EOF), server writes the last prev_line including its CRLF
        assert.are_equal('LINE1\r\nLINE2\r\n', captured)
    end)

    it('accepts large/binary style uploads and writes expected bytes', function()
    local filename = 'large.txt'
        local file_path = fake_settings.stored.home_dir .. '/' .. filename
        local creds = 'admin:secret'
        local cookie = 'UploadsAuthorized=' .. mime.b64(creds)

        local seq = {}
        table.insert(seq, "POST /upload HTTP/1.1")
        table.insert(seq, "Content-Type: multipart/form-data; boundary=LARGEBOUND")
        table.insert(seq, "cookie: " .. cookie)
        table.insert(seq, "")

        push_chars(seq, "--LARGEBOUND\r\n")
        push_chars(seq, 'Content-Disposition: form-data; name="file"; filename="' .. filename .. '"\r\n')
        push_chars(seq, "Content-Type: application/octet-stream\r\n")
        push_chars(seq, "\r\n")

        -- Generate 200 lines of 50 'x' characters and CRLFs to simulate large binary-ish chunks
        local lines = {}
        for i=1,200 do
            local s = string.rep('x', 50) .. '\r\n'
            table.insert(lines, s)
            push_chars(seq, s)
        end

        -- terminating boundary
        push_chars(seq, "--LARGEBOUND--\r\n")

        local captured = ''
        local lfs_mock = { dir = function() return function() return nil end end, attributes = function() return { mode = 'file' } end }

        local resp
        io_helper.with_io_open_mock({ [file_path] = function(mode)
            if mode == 'wb' then
                return { write = function(_, data) captured = captured .. data end, close = function() end }
            end
            return nil
        end }, function()
            resp = helpers.run_server_with_client(seq, { fake_settings = fake_settings, seconds_runtime = 1, injected_modules = { ['libs/libkoreader-lfs'] = lfs_mock } })
        end)

    assert.is_not_nil(resp)
    assert.is_true(resp:match('HTTP/1.1 200 OK') ~= nil)
    -- Content-Type should be text/html; Content-Length should match body
    assert.is_true(resp:match('Content%-Type:%s*text/html') ~= nil)
    local cl = resp:match('Content%-Length:%s*(%d+);')
    assert.is_not_nil(cl)
    local body = resp:match('\r\n\r\n(.*)$') or ''
    assert.are.equal(tonumber(cl), #body)
    assert.is_true(resp:match('File uploaded successfully') ~= nil)
    assert.is_true(body:find(filename, 1, true) ~= nil)

        -- When terminated properly, server trims trailing CRLF of final line; expected is concatenation of lines with final CRLF removed
        local expected = table.concat(lines)
        expected = expected:gsub('[\r\n]+$', '')
        assert.are.equal(expected, captured)
    end)
end)
