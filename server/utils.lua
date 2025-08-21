local url = require("socket.url")
local M = {}

function M.html_escape(str)
    if not str then return "" end
    return tostring(str)
        :gsub('&', '&amp;')
        :gsub('<', '&lt;')
        :gsub('>', '&gt;')
        :gsub('"', '&quot;')
        :gsub("'", '&#39;')
end


function M.url_path_parsing(path)
    local parsed_url = url.parse(path)
    local function parse_query(query)
        local params = {}
        for key, value in string.gmatch(query or "", "([^&=?]-)=([^&=?]+)") do
            params[key] = value
        end
        return params
    end
    return parse_query(parsed_url.query)
end

return M
