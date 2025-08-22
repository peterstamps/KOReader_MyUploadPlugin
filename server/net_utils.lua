local socket = require("socket")

local M = {}

function M.get_ip_address()
    local s = socket.udp()
    local result = s:setpeername("pool.ntp.org",80)
    if not result then
        s:setpeername("north-america.pool.ntp.org",80)
    end
    local ip, _, ip_type = s:getsockname()
    if ip and ip_type == 'inet' then
        return ip
    else
        return "127.0.0.1"
    end
end

local function rule_exists(rule)
    local handle = io.popen("iptables -S")
    if not handle then return false end
    local output = handle:read("*a")
    handle:close()
    return output:find(rule, 1, true) ~= nil
end

local function set_kindle_iptables(port)
    local Device = require("device")
    if Device:isKindle() then
        local input_rule = string.format("-A INPUT -p tcp -m tcp --dport %s -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT", port)
        local output_rule = string.format("-A OUTPUT -p tcp -m tcp --sport %s -m conntrack --ctstate ESTABLISHED -j ACCEPT", port)
        if not rule_exists(input_rule) then
            print("[iptables] Adding INPUT rule for port " .. tostring(port))
            os.execute("iptables " .. input_rule)
        else
            print("[BookDrop - iptables] INPUT rule for port " .. tostring(port) .. " already exists, skipping.")
        end
        if not rule_exists(output_rule) then
            print("[BookDrop - iptables] Adding OUTPUT rule for port " .. tostring(port))
            os.execute("iptables " .. output_rule)
        else
            print("[BookDrop - iptables] OUTPUT rule for port " .. tostring(port) .. " already exists, skipping.")
        end
    else
        print("[BookDrop - iptables] Not a Kindle device, skipping firewall rule changes.")
    end
end

local function remove_kindle_iptables(port)
    local Device = require("device")
    if Device:isKindle() then
        local input_rule = string.format("INPUT -p tcp -m tcp --dport %s -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT", port)
        local output_rule = string.format("OUTPUT -p tcp -m tcp --sport %s -m conntrack --ctstate ESTABLISHED -j ACCEPT", port)
        if rule_exists("-A " .. input_rule) then
            os.execute("iptables -D " .. input_rule)
        else
            print("[BookDrop - iptables] INPUT rule for port " .. tostring(port) .. " does not exist, skipping remove.")
        end
        if rule_exists("-A " .. output_rule) then
            print("[BookDrop - iptables] Removing OUTPUT rule for port " .. tostring(port))
            os.execute("iptables -D " .. output_rule)
        else
            print("[BookDrop - iptables] OUTPUT rule for port " .. tostring(port) .. " does not exist, skipping remove.")
        end
    else
        print("[BookDrop - iptables] Not a Kindle device, skipping firewall rule removal.")
    end
end

return {
    get_ip_address = M.get_ip_address,
    set_kindle_iptables = set_kindle_iptables,
    remove_kindle_iptables = remove_kindle_iptables
}
