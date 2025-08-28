local mime = {}

-- Simple base64 encode/decode implementation suitable for tests.
local bchars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function to_index(ch)
    return (bchars:find(ch, 1, true) or 0) - 1
end

function mime.b64(data)
    local out = {}
    local len = #data
    local i = 1
    while i <= len do
        local c1 = data:byte(i) or 0
        local c2 = data:byte(i+1) or 0
        local c3 = data:byte(i+2) or 0
        local n = c1 * 65536 + c2 * 256 + c3
        local c1i = math.floor(n / 262144) % 64
        local c2i = math.floor(n / 4096) % 64
        local c3i = math.floor(n / 64) % 64
        local c4i = n % 64
        table.insert(out, bchars:sub(c1i+1, c1i+1))
        table.insert(out, bchars:sub(c2i+1, c2i+1))
        table.insert(out, bchars:sub(c3i+1, c3i+1))
        table.insert(out, bchars:sub(c4i+1, c4i+1))
        i = i + 3
    end
    local rem = len % 3
    if rem == 1 then
        out[#out] = '='
        out[#out-1] = '='
    elseif rem == 2 then
        out[#out] = '='
    end
    return table.concat(out)
end

function mime.unb64(data)
    if type(data) ~= 'string' then return nil end
    if data:find('[^%w%+%/=]') then return nil end
    local out = {}
    local i = 1
    while i <= #data do
        local ch1 = data:sub(i,i); i = i + 1
        local ch2 = data:sub(i,i); i = i + 1
        local ch3 = data:sub(i,i); i = i + 1
        local ch4 = data:sub(i,i); i = i + 1
        if not ch1 or not ch2 then return nil end
        local v1 = to_index(ch1)
        local v2 = to_index(ch2)
        local v3 = (ch3 == '=' and 0) or to_index(ch3)
        local v4 = (ch4 == '=' and 0) or to_index(ch4)
        if v1 < 0 or v2 < 0 or v3 < 0 or v4 < 0 then return nil end
        local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
        local byte1 = math.floor(n / 65536) % 256
        local byte2 = math.floor(n / 256) % 256
        local byte3 = n % 256
        table.insert(out, string.char(byte1))
        if ch3 ~= '=' then table.insert(out, string.char(byte2)) end
        if ch4 ~= '=' then table.insert(out, string.char(byte3)) end
    end
    return table.concat(out)
end

return mime
