-- Shared test setup for specs
local M = {}

-- Basic stable mocks
package.loaded['dbg'] = { is_on = false }
package.loaded['logger'] = { dbg = function() end }
package.loaded['gettext'] = function(s) return s end
-- prefer precise module layout for ui/uimanager
local ok_ui, ui_mod = pcall(require, 'spec.support.ui.uimanager')
if ok_ui and ui_mod then
    package.loaded['ui/uimanager'] = ui_mod
else
    package.loaded['ui/uimanager'] = { show = function() end, close = function() end }
end

-- Provide a default socket mock under package.loaded['socket'] using support/socket.lua if present
local ok, sock = pcall(require, 'spec.support.socket')
if ok and sock then
    package.loaded['socket'] = sock
else
    -- fallback basic socket
    package.loaded['socket'] = { udp = function() return { setpeername = function() return true end, getsockname = function() return '192.0.2.5', 12345, 'inet' end } end }
end

-- Helper to require net_utils with custom socket mock
function M.require_net_utils_with_socket(socket_mock)
    package.loaded['socket'] = socket_mock
    package.loaded['bookdrop.net_utils'] = nil
    package.loaded['bookdrop/net_utils'] = nil
    return require('bookdrop.net_utils')
end

return M
