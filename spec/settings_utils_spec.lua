local setup = require('spec.support.init')

-- override bookdrop.net_utils specific mock used by these tests
package.loaded['bookdrop.net_utils'] = { get_ip_address = function() return '10.0.0.1' end }
package.loaded['bookdrop/net_utils'] = { get_ip_address = function() return '10.0.0.1' end }

local M = require('bookdrop.settings_utils')

describe('settings_utils', function()
    it('parse_upload_settings returns empty table when no Upload_parms', function()
        local fake_settings = {
            readSetting = function(self, k) return nil end
        }
        local res = M.parse_upload_settings(fake_settings)
        assert.is_table(res)
        assert.are_equal(0, #res)
    end)

    it('parse_upload_settings parses values and coerces types', function()
        local fake_settings = {
            readSetting = function(self, k)
                if k == 'Upload_parms' then
                    return {
                        ip_address = '192.168.0.5',
                        port = '9090',
                        seconds_runtime = '120',
                        username = 'user',
                        password = 'pass'
                    }
                end
                return nil
            end
        }
        local res = M.parse_upload_settings(fake_settings)
        assert.is_table(res)
        assert.are_equal('192.168.0.5', res.ip_address)
        assert.are_equal(9090, res.port)
        assert.are_equal(120, res.seconds_runtime)
        assert.are_equal('user', res.username)
        assert.are_equal('pass', res.password)
    end)

    it('reset_upload_settings saves defaults and calls on_update', function()
        local called = false
        local saved = nil
        local fake_settings = {
            delSetting = function(self, k) end,
            saveSetting = function(self, k, v) saved = v end
        }
        M.reset_upload_settings(fake_settings, function() called = true end)
        assert.is_true(called)
        assert.is_table(saved)
        assert.are_equal('10.0.0.1', saved.ip_address)
        assert.are_equal(8080, saved.port)
        assert.are_equal(60, saved.seconds_runtime)
        assert.are_equal('admin', saved.username)
        assert.are_equal('1234', saved.password)
    end)
end)
