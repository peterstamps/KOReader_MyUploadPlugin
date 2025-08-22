local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Dispatcher = require("dispatcher")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")
local DataStorage = require("datastorage")
local http_server = require("server/http_server")
local Device = require("device")
local net_utils = require("server/net_utils")
local settings_utils = require("server/settings_utils")

local BookDrop = WidgetContainer:extend{
	name = "BookDrop",
	is_doc_only = false,
}

function BookDrop:onDispatcherRegisterActions()
	Dispatcher:registerAction("AutoStopServer_action", {category="none", event="AutoStopServer", title=_("BookDrop Server"), general=true,})
	Dispatcher:registerAction("RunningServer_action", {category="none", event="RunningServer", title=_("BookDrop Server"), general=true,})
end

function BookDrop:init()
	self:onDispatcherRegisterActions()
	self.ui.menu:registerToMainMenu(self)
end

-- Show the start popup and run the server, passing ip/port as arguments
local function show_start_popup_and_run(upload_seconds_run, ip_address, port)
    local MultiConfirmBox = require("ui/widget/multiconfirmbox")
    local QRMessage = require("ui/widget/qrmessage")
    local dialog
    dialog = MultiConfirmBox:new{
        title = _( "Start BookDrop server" ),
        text = _( "Press Start to begin the BookDrop server." ..
        "\n\nhttp://" .. tostring(ip_address or "127.0.0.1") .. ":" .. tostring(port or "8080") ..
        "\n\nKOReader will appear blocked for ") .. tostring(upload_seconds_run) .. _( " seconds or until the server is manually stopped."),
        choice1_text = _( "Start" ),
        choice1_callback = function()
            net_utils.set_kindle_iptables(port)
            UIManager:close(dialog)
            http_server.start_server()
            BookDrop:AutoStopServer()
        end,
        choice2_text = _( "Show QR Code" ),
        choice2_callback = function()
            local screen_width = Device.screen_width or 758 -- fallback to Kobo Aura default width
            local qr_size = math.floor(screen_width * 0.7)
            local url = "http://" .. tostring(ip_address or "127.0.0.1") .. ":" .. tostring(port or "8080")
            local qr_popup = QRMessage:new{
                text = url,
                width = qr_size,
                height = qr_size,
            }
            UIManager:show(qr_popup)
        end,
    }
    UIManager:show(dialog)
end

function BookDrop:addToMainMenu(menu_items)
    local ip_address = net_utils.get_ip_address()
    local s = settings_utils.parse_upload_settings(G_reader_settings)
    menu_items.BookDrop = {
        text = _( "BookDrop" ),
        sub_item_table = {
            {
                text = "Run BookDrop server. Duration: " .. tostring(s.seconds_runtime) .. "s",
                keep_menu_open = true,
                callback = function()
                    show_start_popup_and_run(s.seconds_runtime, ip_address, s.port)
                end,
            },
            {
                text = "Settings",
                sub_item_table = {
                    {
                        text = "View or Change",
                        keep_menu_open = true,
                        callback = function(touchmenu_instance)
                            settings_utils.show_settings_dialog(G_reader_settings, ip_address, s, touchmenu_instance, function() BookDrop:onUpdateUploadSettings() end)
                        end,
                    },
                    {
                        text = "Reset to defaults",
                        enabled=true,
                        separator=false,
                        callback = function()
                            settings_utils.reset_upload_settings(G_reader_settings, function() BookDrop:onUpdateUploadSettings() end)
                        end
                    },
                },
            },
        }
    }
end

function BookDrop:AutoStopServer()
	local popup = InfoMessage:new{
		text = _( "BookDrop server has been stopped. You may close menu or start the server again"),
	}
	UIManager:show(popup)
end

function BookDrop:onUpdateUploadSettings()
	local popup = InfoMessage:new{
		text = _( "Now restart KOReader for changes to take effect!" ),
	}
	UIManager:show(popup)
end

if G_reader_settings == nil then
    G_reader_settings = require("luasettings"):open(
        DataStorage:getDataDir().."/settings.reader.lua")
end

if G_reader_settings:hasNot("Upload_parms") then
    local default_port = 8080
    local default_username = "admin"
    local default_password = "1234"
    local default_seconds_runtime = 60
    local ip_address = net_utils.get_ip_address()
    G_reader_settings:saveSetting("Upload_parms", {
        ip_address = tostring(ip_address),
        port = tonumber(default_port),
        seconds_runtime = tonumber(default_seconds_runtime),
        username = tostring(default_username),
        password = tostring(default_password)
    })
end

return BookDrop
