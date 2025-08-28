local M = {}

-- Create a fake client that returns a sequence of receive values and captures sent data
local function make_client(receive_lines)
    local recv_i = 0
    local sent = {}
    local client = {}
    function client:receive(pat)
        recv_i = recv_i + 1
        return receive_lines[recv_i]
    end
    function client:send(data)
        table.insert(sent, data)
        return true
    end
    function client:get_sent()
        return table.concat(sent)
    end
    function client:settimeout() end
    function client:close() end
    return client, function() return table.concat(sent) end
end

-- Run the server with a single fake client and return the response sent to that client.
-- opts: { fake_settings = table, injected_modules = { ['module/name']=module }, seconds_runtime = number }
function M.run_server_with_client(receive_lines, opts)
    opts = opts or {}
    local client, get_sent = make_client(receive_lines)

    local socket_mod = package.loaded['socket'] or {}
    local original_bind = socket_mod.bind
    socket_mod.bind = function(_, _)
        return {
            settimeout = function() end,
            accept = function()
                if client then local c = client client = nil return c end
                return nil
            end,
            close = function() end
        }
    end
    package.loaded['socket'] = socket_mod

    -- default settings if none provided
    local default_settings = {
        stored = { Upload_parms = { username = 'admin', password = 'secret', seconds_runtime = opts.seconds_runtime or 1 }, home_dir = '/tmp' },
        readSetting = function(self, k)
            if k == 'Upload_parms' then return self.stored.Upload_parms end
            if k == 'home_dir' then return self.stored.home_dir end
            return nil
        end
    }
    local fake_settings = opts.fake_settings or default_settings
    -- ensure seconds_runtime present
    if fake_settings.stored and fake_settings.stored.Upload_parms then
        fake_settings.stored.Upload_parms.seconds_runtime = fake_settings.stored.Upload_parms.seconds_runtime or opts.seconds_runtime or 1
    end

    package.loaded['luasettings'] = { open = function() return fake_settings end }
    package.loaded['datastorage'] = { getDataDir = function() return '.' end }

    -- Inject any provided modules (e.g., lfs mock)
    if opts.injected_modules then
        for name, mod in pairs(opts.injected_modules) do
            package.loaded[name] = mod
        end
    end

    package.loaded['bookdrop/http_server'] = nil
    local http_server = require('bookdrop/http_server')
    http_server.start_server()

    local resp = get_sent()

    -- restore original socket.bind if present
    if original_bind then socket_mod.bind = original_bind end
    package.loaded['socket'] = socket_mod

    return resp
end

return M
