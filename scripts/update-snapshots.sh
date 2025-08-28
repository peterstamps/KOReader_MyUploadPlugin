#!/usr/bin/env bash
# Regenerate HTML snapshots from templates
set -euo pipefail
cd "$(dirname "$0")/.."
# ensure support path available for lua
lua - <<'LUA'
-- ensure spec support path is available to require
package.path = './spec/support/?.lua;' .. package.path
package.path = package.path .. ";./?.lua;./?/init.lua"
local html = require('bookdrop/html_templates')
local function write(p, s)
  local f = io.open(p, 'wb')
  f:write(s)
  f:close()
end
local snaps = {
  { 'spec/snapshots/header_Test.html', function() return html.header('Test') end },
  { 'spec/snapshots/login_false.html', function() return html.login_page(false) end },
  { 'spec/snapshots/login_true.html', function() return html.login_page(true) end },
  { 'spec/snapshots/shutdown.html', function() return html.shutdown_page() end },
  { 'spec/snapshots/clipping_alert.html', function() return html.clipping_dir_not_set_alert() end },
}
for _, v in ipairs(snaps) do
  local path, fn = v[1], v[2]
  io.write('Writing '..path.."\n")
  write(path, fn())
end
LUA
