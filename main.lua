
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Dispatcher = require("dispatcher")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")
local socket = require("socket")
local DataStorage = require("datastorage")
local http_server = require("server/http_server")
local Device = require("device")

if Device:isKindle() then
        os.execute(string.format("%s %s %s",
            "iptables -A INPUT -p tcp --dport", 8080,
            "-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"))
        os.execute(string.format("%s %s %s",
            "iptables -A OUTPUT -p tcp --sport", 8080,
            "-m conntrack --ctstate ESTABLISHED -j ACCEPT"))
end

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

local function show_start_popup_and_run(upload_seconds_run)
	local MultiConfirmBox = require("ui/widget/multiconfirmbox")
	local QRMessage = require("ui/widget/qrmessage")
	local dialog
	dialog = MultiConfirmBox:new{
		title = _("Start Upload Server"),
		text = _("Press Start to begin the Upload Server." ..
		"\n\nhttp://" .. tostring(Real_ip or "127.0.0.1") .. ":" .. tostring(Port or "8080") ..
		"\n\nKOReader will appear blocked for ") .. tostring(upload_seconds_run) .. _(" seconds or until the server is manually stopped."),
		choice1_text = _("Start"),
		choice1_callback = function()
			UIManager:close(dialog)
			http_server.start_server()
			MyUpload:AutoStopServer()
		end,
		choice2_text = _("Show QR Code"),
		choice2_callback = function()
			local screen_width = Device.screen_width or 758 -- fallback to Kobo Aura default width
			local qr_size = math.floor(screen_width * 0.7)
			local url = "http://" .. tostring(Real_ip or "127.0.0.1") .. ":" .. tostring(Port or "8080")
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

function MyUpload:addToMainMenu(menu_items)
	Check_socket()
---@diagnostic disable-next-line: undefined-field
	local upload_parms = G_reader_settings:readSetting("Upload_parms")
	local upload_parms_port, upload_seconds_run, upload_username, upload_password
	if upload_parms then
		Upload_parms_ip_address =  tostring(Real_ip)
		upload_parms_port = tonumber(upload_parms["port"])
		upload_seconds_run = tonumber(upload_parms["seconds_runtime"])
		upload_username =  tostring(upload_parms["username"])
		upload_password =  tostring(upload_parms["password"])
	end
	menu_items.MyUpload = {
		text = _( "Upload Server" ),
		sub_item_table = {
			{
				text = "Run upload server. Duration: " .. tostring(upload_seconds_run) .. "s",
				keep_menu_open = true,
				callback = function()
					show_start_popup_and_run(upload_seconds_run)
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
										text = upload_parms_port or "",
										input_type = "number",
										hint = _("Port number (default 8080)"),
									},
									{
										text = upload_seconds_run or "",
										input_type = "number",
										hint = _("Runtime range 60-900 seconds (default 60)."),
									},
									{
										text = upload_username or "",
										input_type = "string",
										hint = _("Username for login into Upload server"),
									},
									{
										text = upload_password or "",
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
---@diagnostic disable-next-line: undefined-field
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
			---@diagnostic disable-next-line: undefined-field
										G_reader_settings:delSetting("Upload_parms")
										-- Immediately reset to defaults after deleting
										local default_port = 8080
										local default_username = "admin"
										local default_password = "1234"
										local default_seconds_runtime = 60
										G_reader_settings:saveSetting("Upload_parms", {
											ip_address = tostring(Real_ip),
											port = tonumber(default_port),
											seconds_runtime = tonumber(default_seconds_runtime),
											username = tostring(default_username),
											password = tostring(default_password)
										})
										MyUpload:onUpdateUploadSettings()
						end
					},
				},
			},
		}
	}
end

function MyUpload:AutoStopServer()
	local popup = InfoMessage:new{
		text = _( "Upload Server has been stopped automatically. You may close menu or start the server again"),
	}
	UIManager:show(popup)
end

function MyUpload:onUpdateUploadSettings()
	local popup = InfoMessage:new{
		text = _( "Now restart KOReader for changes to take effect!" ),
	}
	UIManager:show(popup)
end

function Check_socket()
	local s = socket.udp()
	local result = s:setpeername("pool.ntp.org",80)
	if not result then
		s:setpeername("north-america.pool.ntp.org",80)
	end
	local ip, _, ip_type = s:getsockname()
	if ip and ip_type == 'inet' then
		Real_ip = ip
	else
		Real_ip = "127.0.0.1"
	end
end

Check_socket()

if G_reader_settings == nil then
	G_reader_settings = require("luasettings"):open(
		DataStorage:getDataDir().."/settings.reader.lua")
end

if G_reader_settings:hasNot("Upload_parms") then
	local default_port = 8080
	local default_username = "admin"
	local default_password = "1234"
	local default_seconds_runtime = 60
	G_reader_settings:saveSetting("Upload_parms", {
		ip_address = tostring(Real_ip),
		port = tonumber(default_port),
		seconds_runtime = tonumber(default_seconds_runtime),
		username = tostring(default_username),
		password = tostring(default_password)
	})
end

if G_reader_settings:has("Upload_parms") then
	local Upload_parms = G_reader_settings:readSetting("Upload_parms")
	if Upload_parms then
		Port = tonumber(Upload_parms["port"])
		Seconds_runtime = tonumber(Upload_parms["seconds_runtime"])
		Username = tostring(Upload_parms["username"])
		Password = tostring(Upload_parms["password"])
	end
end

print('Defaults: ip: ' .. tostring(Real_ip) .. ', port: ' .. tostring(Port) ..', runtime (seconds): ' .. tostring(Seconds_runtime) )
print('Defaults: username: ' .. tostring(Username) .. ', password: ' .. tostring(Password) )
return MyUpload
