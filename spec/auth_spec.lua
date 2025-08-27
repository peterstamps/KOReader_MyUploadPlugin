-- Ensure spec support folder is on package.path so test-only modules like mime are resolved
package.path = package.path .. ";./spec/support/?.lua"
local auth = require("bookdrop/auth")
local mime = require("mime")

describe("bookdrop/auth.lua", function()
    describe("parse_cookies", function()
        it("parses cookie header and returns cookie table and specific cookie value", function()
            local headers = { cookie = "a=1; b=two; UploadsAuthorized=abc123; last=ok" }
            local cookies, specific = auth.parse_cookies(headers, "UploadsAuthorized")
            assert.is_table(cookies)
            assert.equals("1", cookies.a)
            assert.equals("two", cookies.b)
            assert.equals("abc123", cookies.UploadsAuthorized)
            assert.equals("abc123", specific)
        end)

        it("handles missing cookie header", function()
            local headers = {}
            local cookies, specific = auth.parse_cookies(headers, "UploadsAuthorized")
            assert.is_table(cookies)
            assert.is_nil(specific)
            assert.is_true(next(cookies) == nil)
        end)
    end)

    describe("validate_password", function()
        local fake_settings = {
            stored = { Upload_parms = { username = "admin", password = "1234" } },
            readSetting = function(self, k)
                if k == "Upload_parms" then return self.stored.Upload_parms end
                return nil
            end
        }

        it("returns true for correct username/password", function()
            assert.is_true(auth.validate_password("admin", "1234", fake_settings))
        end)

        it("returns false for incorrect username", function()
            assert.is_false(auth.validate_password("wrong", "1234", fake_settings))
        end)

        it("returns false for incorrect password", function()
            assert.is_false(auth.validate_password("admin", "bad", fake_settings))
        end)

        it("returns false when Upload_parms missing", function()
            local empty_settings = { readSetting = function() return nil end }
            assert.is_false(auth.validate_password("admin", "1234", empty_settings))
        end)
    end)

    describe("is_authorized", function()
        local fake_settings = {
            stored = { Upload_parms = { username = "admin", password = "1234" } },
            readSetting = function(self, k)
                if k == "Upload_parms" then return self.stored.Upload_parms end
                return nil
            end
        }

        it("returns false when cookie not present", function()
            local headers = {}
            assert.is_false(auth.is_authorized(headers, fake_settings))
        end)

        it("returns true for valid UploadsAuthorized cookie", function()
            local creds = "admin:1234"
            local encoded = mime.b64(creds)
            local headers = { cookie = "foo=bar; UploadsAuthorized=" .. encoded .. "; x=1" }
            assert.is_true(auth.is_authorized(headers, fake_settings))
        end)

        it("returns false for invalid credentials in cookie", function()
            local creds = "bad:creds"
            local encoded = mime.b64(creds)
            local headers = { cookie = "UploadsAuthorized=" .. encoded }
            assert.is_false(auth.is_authorized(headers, fake_settings))
        end)

        it("returns false for malformed base64 cookie", function()
            local headers = { cookie = "UploadsAuthorized=not-base64!!!" }
            assert.is_false(auth.is_authorized(headers, fake_settings))
        end)
    end)
end)
