local support = require('spec.support.init')

local function require_net_utils_with_socket(socket_mock)
    return support.require_net_utils_with_socket(socket_mock)
end

describe('net_utils', function()
    describe('get_ip_address', function()
        it('returns the IP when getsockname reports inet', function()
            local socket_mock = { udp = function()
                return { setpeername = function() return true end, getsockname = function() return '5.6.7.8', 1234, 'inet' end }
            end }
            local net_utils = require_net_utils_with_socket(socket_mock)
            assert.are_equal('5.6.7.8', net_utils.get_ip_address())
        end)

        it('returns 127.0.0.1 when getsockname is not inet', function()
            local socket_mock = { udp = function()
                return { setpeername = function() return true end, getsockname = function() return nil, nil, nil end }
            end }
            local net_utils = require_net_utils_with_socket(socket_mock)
            assert.are_equal('127.0.0.1', net_utils.get_ip_address())
        end)
    end)

    describe('iptables manipulation', function()
        local orig_io_popen, orig_os_execute
        setup(function()
            orig_io_popen = io.popen
            orig_os_execute = os.execute
        end)
        teardown(function()
            io.popen = orig_io_popen
            os.execute = orig_os_execute
        end)

        it('adds iptables rules when device is Kindle and rules missing', function()
            -- device is Kindle
            package.loaded['device'] = { isKindle = function() return true end }
            -- io.popen returns empty output -> no rules exist
            io.popen = function(cmd)
                local handle = {}
                function handle:read(_) return '' end
                function handle:close() end
                return handle
            end
            local executed = {}
            os.execute = function(cmd) table.insert(executed, cmd) return 0 end

            local socket_mock = { udp = function() return { setpeername = function() return true end, getsockname = function() return '1.2.3.4', 1234, 'inet' end } end }
            local net_utils = require_net_utils_with_socket(socket_mock)
            net_utils.set_kindle_iptables(8080)

            -- Expect two iptables add commands were executed
            local found_add_input = false
            local found_add_output = false
            for _,c in ipairs(executed) do
                if c:find('-A INPUT', 1, true) then found_add_input = true end
                if c:find('-A OUTPUT', 1, true) then found_add_output = true end
            end
            assert.is_true(found_add_input)
            assert.is_true(found_add_output)
        end)

        it('removes iptables rules when device is Kindle and rules exist', function()
            package.loaded['device'] = { isKindle = function() return true end }
            -- io.popen returns a string that contains the rules (-A ...)
            io.popen = function(cmd)
                local handle = {}
                function handle:read(_) return '-A INPUT -p tcp -m tcp --dport 8080 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT\n-A OUTPUT -p tcp -m tcp --sport 8080 -m conntrack --ctstate ESTABLISHED -j ACCEPT' end
                function handle:close() end
                return handle
            end
            local executed = {}
            os.execute = function(cmd) table.insert(executed, cmd) return 0 end

            local socket_mock = { udp = function() return { setpeername = function() return true end, getsockname = function() return '1.2.3.4', 1234, 'inet' end } end }
            local net_utils = require_net_utils_with_socket(socket_mock)
            net_utils.remove_kindle_iptables(8080)

            local found_del_input = false
            local found_del_output = false
            for _,c in ipairs(executed) do
                if c:find('-D INPUT', 1, true) then found_del_input = true end
                if c:find('-D OUTPUT', 1, true) then found_del_output = true end
            end
            assert.is_true(found_del_input)
            assert.is_true(found_del_output)
        end)

        it('does not call iptables when device is not Kindle', function()
            package.loaded['device'] = { isKindle = function() return false end }
            io.popen = function(cmd)
                local handle = {}
                function handle:read(_) return '' end
                function handle:close() end
                return handle
            end
            local executed = {}
            os.execute = function(cmd) table.insert(executed, cmd) return 0 end

            local socket_mock = { udp = function() return { setpeername = function() return true end, getsockname = function() return '1.2.3.4', 1234, 'inet' end } end }
            local net_utils = require_net_utils_with_socket(socket_mock)
            net_utils.set_kindle_iptables(8080)
            net_utils.remove_kindle_iptables(8080)
            assert.are_equal(0, #executed)
        end)
    end)
end)
