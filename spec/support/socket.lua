local M = {}

function M.udp()
    local obj = {}
    function obj:setpeername(host, port)
        -- pretend success
        return true
    end
    function obj:getsockname()
        -- return ip, port, ip_type
        return '192.0.2.5', 12345, 'inet'
    end
    return obj
end

return M
local M = {}

function M.udp()
    local obj = {}
    function obj:setpeername(host, port)
        -- pretend success
        return true
    end
    function obj:getsockname()
        -- return ip, port, ip_type
        return '192.0.2.5', 12345, 'inet'
    end
    return obj
end

return M
