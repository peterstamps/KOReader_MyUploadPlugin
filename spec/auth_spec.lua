package.path = package.path .. ";./spec/support/?.lua"
local auth = require('bookdrop/auth')
local mime = require('mime')

describe('bookdrop/auth', function()
  describe('parse_cookies', function()
    it('parses multiple cookies and returns specific cookie when requested', function()
      local headers = { cookie = 'a=1; UploadsAuthorized=XYZ; other=foo' }
      local cookies, specific = auth.parse_cookies(headers, 'UploadsAuthorized')
      assert.is_table(cookies)
      assert.are.equal('1', cookies['a'])
      assert.are.equal('XYZ', cookies['UploadsAuthorized'])
      assert.are.equal('XYZ', specific)
    end)

    it('trims whitespace and ignores malformed cookies', function()
      local headers = { cookie = '  foo = bar  ; badcookie ; baz=qux ' }
      local cookies, specific = auth.parse_cookies(headers, 'baz')
      assert.are.equal('bar', cookies['foo'])
      assert.is_nil(cookies['badcookie'])
      assert.are.equal('qux', specific)
    end)

    it('handles missing cookie header', function()
      local cookies, specific = auth.parse_cookies({}, 'UploadsAuthorized')
      assert.is_table(cookies)
      assert.is_nil(next(cookies))
      assert.is_nil(specific)
    end)
  end)

  describe('validate_password', function()
    local fake_settings = {
      stored = { Upload_parms = { username = 'admin', password = '1234' } },
      readSetting = function(self, k)
        if k == 'Upload_parms' then return self.stored.Upload_parms end
        return nil
      end
    }

    it('returns true for correct username/password', function()
      assert.is_true(auth.validate_password('admin', '1234', fake_settings))
    end)

    it('returns false for incorrect username', function()
      assert.is_false(auth.validate_password('wrong', '1234', fake_settings))
    end)

    it('returns false for incorrect password', function()
      assert.is_false(auth.validate_password('admin', 'bad', fake_settings))
    end)

    it('returns false when Upload_parms missing', function()
      local empty_settings = { readSetting = function() return nil end }
      assert.is_false(auth.validate_password('admin', '1234', empty_settings))
    end)
  end)

  describe('is_authorized', function()
    local fake_settings = {
      stored = { Upload_parms = { username = 'admin', password = '1234' } },
      readSetting = function(self, k)
        if k == 'Upload_parms' then return self.stored.Upload_parms end
        return nil
      end
    }

    it('returns false when cookie not present', function()
      local headers = {}
      assert.is_false(auth.is_authorized(headers, fake_settings))
    end)

    it('returns true for valid UploadsAuthorized cookie', function()
      local creds = 'admin:1234'
      local encoded = mime.b64(creds)
      local headers = { cookie = 'foo=bar; UploadsAuthorized=' .. encoded .. '; x=1' }
      assert.is_true(auth.is_authorized(headers, fake_settings))
    end)

    it('returns false for invalid credentials in cookie', function()
      local creds = 'bad:creds'
      local encoded = mime.b64(creds)
      local headers = { cookie = 'UploadsAuthorized=' .. encoded }
      assert.is_false(auth.is_authorized(headers, fake_settings))
    end)

    it('returns false for malformed base64 cookie', function()
      local headers = { cookie = 'UploadsAuthorized=not-base64!!!' }
      assert.is_false(auth.is_authorized(headers, fake_settings))
    end)

    it('returns false when decoded cookie is malformed (no colon or empty password)', function()
      local headers1 = { cookie = 'UploadsAuthorized=' .. mime.b64('no-colon-value') }
      assert.is_false(auth.is_authorized(headers1, fake_settings))
      local headers2 = { cookie = 'UploadsAuthorized=' .. mime.b64('user:') }
      assert.is_false(auth.is_authorized(headers2, fake_settings))
    end)
  end)
end)

