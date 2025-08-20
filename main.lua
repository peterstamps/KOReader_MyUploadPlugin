
-- This is a plugin to Start and Stop an Upload Server.

local BD = require("ui/bidi")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local QRMessage = require("ui/widget/qrmessage")
local Device = require("device")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local C_ = _.pgettext
local T = require("ffi/util").template
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local socket = require("socket")

-- Refactored modules
local file_utils = require("server/file_utils")
local auth = require("server/auth")
local html = require("server/html_templates")
local utils = require("server/utils")
local http_server = require("server/http_server")

local MyUpload = WidgetContainer:extend{
	name = "MyUpload",
	is_doc_only = false,
}

function MyUpload:onDispatcherRegisterActions()
	Dispatcher:registerAction("AutoStopServer_action", {category="none", event="AutoStopServer", title=_("My Upload Server"), general=true,})
	Dispatcher:registerAction("RunningServer_action", {category="none", event="RunningServer", title=_("My Upload Server"), general=true,})
end

function MyUpload:init()
	self:onDispatcherRegisterActions()
	self.ui.menu:registerToMainMenu(self)
end

local function start_server()
	http_server.start_server()
end

function MyUpload:addToMainMenu(menu_items)
	check_socket()
	local Upload_parms = G_reader_settings:readSetting("Upload_parms")
	local Upload_parms_port, Upload_seconds_run, Upload_username, Upload_password
	if Upload_parms then
		Upload_parms_ip_address =  tostring(real_ip)
		Upload_parms_port = tonumber(Upload_parms["port"])
		Upload_seconds_run = tonumber(Upload_parms["seconds_runtime"])
		Upload_username =  tostring(Upload_parms["username"])
		Upload_password =  tostring(Upload_parms["password"])
	end
	menu_items.MyUpload = {
		text = _( "Upload Server" ),
		sub_item_table = {
			{
				text = "Start Upload server. Stops after " .. tostring(seconds_runtime) .. "s",
				keep_menu_open = true,
				callback = function()
					start_server()
					MyUpload:AutoStopServer()
				end,
			},
			{
				text = "Settings",
				sub_item_table = {
					{
						text = "View or Change",
						keep_menu_open = true,
						callback = function(touchmenu_instance)
							local MultiInputDialog = require("ui/widget/multiinputdialog")
							local url_dialog
							url_dialog = MultiInputDialog:new{
								title = _("Upload settings: ip, port, runtime, username, password"),
								fields = {
									{
										text = Upload_parms_ip_address or "",
										input_type = "string",
										hint = _("nil or 127.0.0.1? Set to IP address of ereader!"),
									},
									{
										text = Upload_parms_port or "",
										input_type = "number",
										hint = _("Port number (default 8080)"),
									},
									{
										text = Upload_seconds_run or "",
										input_type = "number",
										hint = _("Runtime range 60-900 seconds (default 60)."),
									},
									{
										text = Upload_username or "",
										input_type = "string",
										hint = _("Username for login into Upload server"),
									},
									{
										text = Upload_password or "",
										input_type = "string",
										hint = _("password"),
									},
								},
								buttons = {
									{
										{
											text = _("Cancel"),
											id = "close",
											callback = function()
												UIManager:close(url_dialog)
											end,
										},
										{
											text = _("OK"),
											callback = function()
												local fields = url_dialog:getFields()
												local ip_address = fields[1]
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
												if not ip_address or ip_address == "" or not is_ipv4{args={ip_address}} then
													ip_address = '127.0.0.1'
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
													ip_address = tostring(ip_address),
													port = tonumber(new_port),
													seconds_runtime = tonumber(new_seconds_runtime),
													username = tostring(new_username),
													password = tostring(new_password)
												})
												UIManager:close(url_dialog)
												if touchmenu_instance then touchmenu_instance:updateItems() end
												MyUpload:onUpdateUploadSettings()
											end,
										},
									},
								},
							}
							UIManager:show(url_dialog)
							url_dialog:onShowKeyboard()
						end,
					},
					{
						text = "Reset to defaults",
						enabled=true,
						separator=false,
						callback = function()
							G_reader_settings:delSetting("Upload_parms")
							MyUpload:onUpdateUploadSettings()
						end
					},
				},
			},
		}
	}
end

function MyUpload:AutoStopServer()
	local text_part = 'automatically'
	local popup = InfoMessage:new{
		text = _( "Upload Server has been stopped " .. text_part ..". You may close menu or start Upload server again" ),
	}
	UIManager:show(popup)
end

function MyUpload:onUpdateUploadSettings()
	local popup = InfoMessage:new{
		text = _( "Now restart KOReader for changes to take effect!" ),
	}
	UIManager:show(popup)
end

function check_socket()
	local s = socket.udp()
	local result = s:setpeername("pool.ntp.org",80)
	if not result then
		s:setpeername("north-america.pool.ntp.org",80)
	end
	local ip, lport, ip_type = s:getsockname()
	if ip and ip_type == 'inet' then
		real_ip = ip
	else
		real_ip = "127.0.0.1"
	end
end

check_socket()

if G_reader_settings == nil then
	G_reader_settings = require("luasettings"):open(
		DataStorage:getDataDir().."/settings.reader.lua")
end

if G_reader_settings:hasNot("Upload_parms") then
	local default_ip_address = "*"
	local default_port = 8080
	local default_username = "admin"
	local default_password = "1234"
	local default_seconds_runtime = 60
	G_reader_settings:saveSetting("Upload_parms", {ip_address = tostring(real_ip), port = tonumber(default_port), seconds_runtime = tonumber(default_seconds_runtime), username = tostring(default_username), password = tostring(default_password) })
end

if G_reader_settings:has("Upload_parms") then
	local Upload_parms = G_reader_settings:readSetting("Upload_parms")
	local Upload_parms_port, Upload_seconds_run, Upload_username, Upload_password
	if Upload_parms then
		Upload_parms_ip_address = tostring(Upload_parms["ip_address"])
		port = tonumber(Upload_parms["port"])
		seconds_runtime = tonumber(Upload_parms["seconds_runtime"])
		username =  tostring(Upload_parms["username"])
		password =  tostring(Upload_parms["password"])
	end
end

print('Defaults: ip: ' .. tostring(real_ip) .. ', port: ' .. tostring(port) ..', runtime (seconds): ' .. tostring(seconds_runtime) )

return MyUpload
