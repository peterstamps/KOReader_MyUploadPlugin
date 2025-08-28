-- Thin wrapper to initialize common mocks and re-export helpers
local init = require('spec.support.init')
local M = {}
M.require_net_utils_with_socket = init.require_net_utils_with_socket
return M
