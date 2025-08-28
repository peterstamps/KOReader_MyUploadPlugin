local mime = require("mime")

local M = {}

function M.parse_cookies(headers, cookie_name)
    local cookies = {}
    local specific_cookie_value = nil
    if headers["cookie"] then
        local function trim(s)
            return (s:gsub("^%s*(.-)%s*$", "%1"))
        end
        for cookie in headers["cookie"]:gmatch("([^;]+)") do
            local key, value = cookie:match("([^=]+)=([^;]+)")
            if key and value then
                key = trim(key)
                value = trim(value)
                cookies[key] = value
                if cookie_name and key == cookie_name then
                    specific_cookie_value = value
                end
            end
        end
    end
    return cookies, specific_cookie_value
end

function M.validate_password(username, password, G_reader_settings)
    local Upload_parms = G_reader_settings:readSetting("Upload_parms")
    if Upload_parms then
        local Upload_username = tostring(Upload_parms["username"])
        local Upload_password = tostring(Upload_parms["password"])
        return tostring(username) == Upload_username and tostring(password) == Upload_password
    end
    return false
end

function M.is_authorized(headers, G_reader_settings)
    local _, specific_cookie_value = M.parse_cookies(headers, 'UploadsAuthorized')
    if not specific_cookie_value then return false end
    local decoded_credentials = mime.unb64(specific_cookie_value)
    if not decoded_credentials then return false end
    local username, password = decoded_credentials:match("([^:]+):(.+)")
    if not username or not password then return false end
    return M.validate_password(username, password, G_reader_settings)
end

return M
