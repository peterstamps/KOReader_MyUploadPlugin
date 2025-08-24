local net_utils = require("bookdrop/net_utils")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local M = {}

function M.parse_upload_settings(G_reader_settings)
    local upload_parms = G_reader_settings:readSetting("Upload_parms")
    if not upload_parms then return {} end
    return {
        ip_address = upload_parms.ip_address,
        port = tonumber(upload_parms.port),
        seconds_runtime = tonumber(upload_parms.seconds_runtime),
        username = tostring(upload_parms.username),
        password = tostring(upload_parms.password)
    }
end

function M.show_settings_dialog(G_reader_settings, ip_address, upload_settings, touchmenu_instance, on_update)
    local MultiInputDialog = require("ui/widget/multiinputdialog")
    local url_dialog
    url_dialog = MultiInputDialog:new{
        title = _("Upload settings: ip, port, runtime, username, password"),
        fields = {
            { text = upload_settings.ip_address or ip_address or "", input_type = "string", hint = _("nil or 127.0.0.1? Set to IP address of ereader!") },
            { text = upload_settings.port or "", input_type = "number", hint = _("Port number (default 8080)") },
            { text = upload_settings.seconds_runtime or "", input_type = "number" },
            { text = upload_settings.username or "", input_type = "string" },
            { text = upload_settings.password or "", input_type = "string", hint = _("password") },
        },
        buttons = {
            {
                { text = _("Cancel"), id = "close", callback = function() UIManager:close(url_dialog) end },
                { text = _("OK"),
                callback = function()
                    local fields = url_dialog:getFields()
                    local ip_address_new = fields[1]
                    local function is_ipv4(opts)
                        local ip = opts.args[1] or opts.args.ip
                        if not ip then return false end
                        if ip == "*" or ip == "0.0.0.0" then return true end
                        local chunks = {{ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}}
                        if #chunks[1] == 4 then
                            for _,v in ipairs(chunks[1]) do
                                local n = tonumber(v)
                                if not n or n < 0 or n > 255 then return false end
                            end
                            return true
                        end
                        return false
                    end
                    if not ip_address_new or ip_address_new == "" or not is_ipv4{args={ip_address_new}} then
                        ip_address_new = '127.0.0.1'
                    end
                    local new_port = tonumber(fields[2]) or 8080
                    if new_port < 1 or new_port > 65355 then new_port = 8080 end
                    local new_seconds_runtime = tonumber(fields[3]) or 60
                    if new_seconds_runtime < 30 or new_seconds_runtime > 900 then new_seconds_runtime = 60 end
                    local new_username = fields[4] or "admin"
                    if new_username == "" then new_username = "admin" end
                    local new_password = fields[5] or "1234"
                    if new_password == "" then new_password = "1234" end
                    G_reader_settings:saveSetting("Upload_parms", {
                        ip_address = tostring(ip_address_new),
                        port = tonumber(new_port),
                        seconds_runtime = tonumber(new_seconds_runtime),
                        username = tostring(new_username),
                        password = tostring(new_password)
                    })
                    UIManager:close(url_dialog)
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                    if on_update then on_update() end
                end },
            }
        },
    }
    UIManager:show(url_dialog)
    url_dialog:onShowKeyboard()
end

function M.reset_upload_settings(G_reader_settings, on_update)
    G_reader_settings:delSetting("Upload_parms")
    local default_port = 8080
    local default_username = "admin"
    local default_password = "1234"
    local default_seconds_runtime = 60
    local ip_address_reset = net_utils.get_ip_address()
    G_reader_settings:saveSetting("Upload_parms", {
        ip_address = tostring(ip_address_reset),
        port = tonumber(default_port),
        seconds_runtime = tonumber(default_seconds_runtime),
        username = tostring(default_username),
        password = tostring(default_password)
    })
    if on_update then on_update() end
end

return M
