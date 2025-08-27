local M = {}

function M.udp()
    local obj = {}
    function obj:setpeername(host, port)
        return true
    end
    function obj:getsockname()
        return '192.0.2.5', 12345, 'inet'
    end
    return obj
end

return M
