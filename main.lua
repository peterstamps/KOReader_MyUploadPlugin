--[[--
This is a plugin to Start and Stop a Upload Server.

@module MyUpload
--]]--

local BD = require("ui/bidi")
local Dispatcher = require("dispatcher")  -- luacheck:ignore
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
-- loads the URL module 
local url = require("socket.url")
local io = require("io")
local os = require("os")
local string = require("string")
local http = require("socket.http")
http.TIMEOUT = 60  -- Set a larger timeout (in seconds)
local ltn12 = require("ltn12")
local mime = require("mime")
local lfs = require("libs/libkoreader-lfs")

local sock = require("socket")
-- print('version=',sock._VERSION)


-- Get the ereader settings when not defined
if G_reader_settings == nil then
    G_reader_settings = require("luasettings"):open(
        DataStorage:getDataDir().."/settings.reader.lua")
end

-- Set the default Home folder = base ebooks folder on the ereader when not defined
if G_reader_settings:hasNot("home_dir") then
	G_reader_settings:saveSetting("home_dir", ".")
end
-- Get the base ebooks folder on the ereader to start the search for ebooks
ebooks_dir_to_list =  G_reader_settings:readSetting("home_dir")
upload_dir = ebooks_dir_to_list  -- we save books in the Home directory that has been set

-- Set the default Clipboard folder = base ebooks folder on the ereader when not defined
if G_reader_settings:hasNot("exporter") then
	G_reader_settings:saveSetting("exporter", {clipping_dir = tostring(ebooks_dir_to_list)})
end

-- Get the Clippings folder on the ereader to start the search for Clipping files
Exporter_parms = G_reader_settings:readSetting("exporter")

clipping_dir = 'None'
if Exporter_parms then
	if not Exporter_parms["clipping_dir"] then
		clipping_dir = 'None'
	else
		clipping_dir =  tostring(Exporter_parms["clipping_dir"]) 
	end
end

-- Create a simple HTTP response with proper headers, body and cookie
function send_response(client, status, content_type, body, cookie)
    local response = "HTTP/1.1 " .. status .. "\r\n"
    response = response .. "Content-Type: " .. content_type .. ";\r\n"    
    -- If a cookie is provided, include it in the response headers
    if cookie then
        response = response .. "Set-Cookie: " .. cookie .. ";\r\n" -- Note the ; is important!
    end
    response = response .. "Content-Length: " .. #body .. ";\r\n"
    response = response .. "\r\n" -- End of headers
    response = response .. body
    client:send(response)
end

-- Create a simple HTTP response location
function send_response_location(client, status, location, cookie)
    local response = "HTTP/1.1 " .. status .. "\r\n"
    response = response .. "Location: " .. location .. "\r\n"    
    response = response .. "\r\n" -- End of headers
    client:send(response)
end

local function html_paging_part1(table_head)
return [[
    <table id="dataTable">]] .. table_head ..
        [[<tbody>]]
end

local function html_paging_part2()

return [[   
 </tbody>
    </table>

    <div class="pagination">
        <button id="prevBtn" onclick="changePage(-1)">Previous</button>
        <span id="pageInfo">Page 1</span><span id="pageInfoTotal"></span>
        <button id="nextBtn" onclick="changePage(1)">Next</button> 
        Jump to Page: 
        <input type="number" id="pageInput" min="1" placeholder="Page" onchange="jumpToPage()">
        <button id="jumpBtn" onclick="jumpToPage()">Go</button>
	    </div>

    <script>
        // Variables for pagination
        const rowsPerPage = 10;
        let currentPage = 1;

        // Get all rows in the tbody (they are already present in the HTML)
        const tableBody = document.querySelector("#dataTable tbody");
        const rows = Array.from(tableBody.rows);  // Convert rows to an array

        // Function to render the rows for the current page
        function renderTable() {
            // Calculate the rows to display based on the current page
            const startIndex = (currentPage - 1) * rowsPerPage;
            const endIndex = Math.min(startIndex + rowsPerPage, rows.length);

            // Clear the current rows from the table body
            tableBody.innerHTML = "";

            // Append only the rows that should be visible on the current page
            for (let i = startIndex; i < endIndex; i++) {
                tableBody.appendChild(rows[i]);
            }

            // Update the page number information
            document.getElementById("pageInfo").textContent = `Page ${currentPage}`;
            
            // Update the state of the pagination buttons
            updatePaginationButtons();
        }

        // Function to handle the page change (forward or backward)
        function changePage(direction) {
            const newPage = currentPage + direction;
            if (newPage > 0 && newPage <= Math.ceil(rows.length / rowsPerPage)) {
                currentPage = newPage;
                renderTable();
            }
        }

        // Function to update the pagination buttons' state (disable when appropriate)
        function updatePaginationButtons() {
            const totalPages = Math.ceil(rows.length / rowsPerPage);
            document.getElementById("prevBtn").disabled = currentPage === 1;
            document.getElementById("nextBtn").disabled = currentPage === totalPages;
            document.getElementById("pageInfoTotal").textContent = ` of ${totalPages}`;
        }

        // Function to jump to a specific page entered by the user
        function jumpToPage() {
            const inputPage = parseInt(document.getElementById("pageInput").value);
            const totalPages = Math.ceil(rows.length / rowsPerPage);

            if (inputPage >= 1 && inputPage <= totalPages) {
                currentPage = inputPage;
                renderTable();
            } else {
                alert("Invalid page number!");
            }
        }

        // Initial render when the page loads
        renderTable();
    </script>
]]
end

-- Generate HTML header
local function html_header(title)
    return [[
            <!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>]] .. title .. [[</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f2f2f2; }
        .container { max-width: 100%; margin: auto; padding: 10px; background-color: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        input { width: 100%; padding: 10px; margin: 10px 0; }
        input[type=submit] { width: 50%; background-color: #4CAF50;padding: 10px; margin: 10px 0; }
        input[type=number] { width: 50px;padding: 5px; margin: 5px 0; }
        #prevBtn, #nextBtn, #jumpBtn { width: 10%; background-color: #4CAF50;padding: 10px; margin: 10px 0; }
        a {color: blue; text-decoration: none;}
        input[type=submit]:hover { background-color: #45a049;}
        button { padding: 10px; width: 100%; background-color: #4CAF50; color: white; border: none; cursor: pointer; }
        button:hover { background-color: #45a049; }
        .error { color: red; font-size: 14px; margin: 10px 0; }
        .show-password { margin-top: 10px; }
    </style>
    <script>
        function validateFile() {
            const fileInput = document.getElementById('fileUpload');
            const files = fileInput.files;
            const allowedExtensions = /(\.gz)|(\.zip)|(\.tar)$/i;

            for (let i = 0; i < files.length; i++) {
                if (allowedExtensions.test(files[i].name)) {
                    alert("Error: .gz, .zip and .tar files are not allowed.\nUpload only supported files!");
                    fileInput.value = ''; // Clear the input
                    return false; // Prevent form submission
                }
            }
            return true; // Allow form submission
        }
    </script>  
</head>
<body>
    <html>
    <head>
    <title></title>
    <style>
        body {font-family: Arial, sans-serif;}
        table {border-collapse: collapse; width: 100%;}
        table, th, td {border: 1px solid black; text-align:left}
        th, td {padding: 8px;}
       
        .nav {margin-top: 20px;padding: 5px;}
    </style>
    <script>
    </script>
    </head>

    <body>
        <div class="container">
        <div class="nav">
    <a href="/home">Home</a> | <a href="/upload">Upload eBooks</a> | <a href="/clipping_dir">List Clipboard folder</a> | <a href="/files">List Home folder</a> | <a href="/folders">List eBooks in folders |  <a href="/flat_view_files">List All eBooks | <b><a href="/logout">Logout</b>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;<b><a href="/stop">Stop</b></a>
    </div><br>
    <h1>]] .. title .. [[</h1>
    ]]
end

-- Generate HTML footer
local function html_footer()
    return [[
    <div class="nav">
    <a href="/home">Home</a>
    </div>
    </div>
    </body>
    </html>
    ]]
end

-- List files in the root directory recursively
local function list_files(dir)
	if string.len(dir) == 0  then
	  dir = '.'
	end
    local files = {}
    for file in lfs.dir(dir) do
        local full_path = dir .. "/" .. file 
        if file ~= "." and file ~= ".." then
            if lfs.attributes(full_path, "mode") == "file" then
                table.insert(files, file)
            end
        end
    end
    return files
end

-- List all folders and subfolders
local function list_folders(dir)
    local function recurse_dir(dir)
        local folders = {}
        for file in lfs.dir(dir) do
			local full_path = dir .. "/" .. file			
			if file ~= "." and file ~= ".." then
				local mode = lfs.attributes(full_path, "mode")
				if mode == "directory" then
					table.insert(folders, full_path)
					local subfolders = recurse_dir(full_path)
					for _, subfolder in ipairs(subfolders) do
						table.insert(folders, subfolder)
					end
				else
				   -- Data declarations of allow file extensions to be Viewed and/or Downloadable
					local extentions = {"epub", "pdf", "azw3", "mobi", "docx", "txt", "cbz", "json", "sqlite"}
					if extMatch(extentions, full_path) == true then
					 table.insert(folders, full_path)
					end
				end
			end			
        end
        return folders
    end
    return recurse_dir(dir)
end

-- Save uploaded file to the server
function save_uploaded_file(data, filename)
    local file_path = upload_dir .. "/" .. filename
    local file = io.open(file_path, "wb")
    if file then
        file:write(data)
        file:close()
    end
end

-- Function to get file properties for a file
function get_properties(file_path)
    -- Get file attributes using lfs.attributes
    local attributes = lfs.attributes(file_path)
    
    if attributes then
        -- Get file size (similar to getcontentlength)
        local file_size = attributes.size

        -- Get last modified date (similar to getlastmodified)
        local last_modified = os.date("%a, %d %b %Y %H:%M:%S GMT", attributes.modification)

        -- Return the properties
        return {
            getcontentlength = file_size,
            getlastmodified = last_modified
        }
    else
        -- Return nil if the file doesn't exist
        return nil
    end
end

-- Handle file download
function download_file(file_name, client_socket)
    local file_path = file_name
    --print('file_path3 , file_name3 :', file_path , file_name)
    local file = io.open(file_path, "rb")
    if file then
        local properties = get_properties(file_path)
        local file_data = file:read("*all")
        file:close()
		local path, file_to_download, extension = string.match(file_path, "(.-)([^\\/]-%.?([^%.\\/]*))$")	
		local response = "HTTP/1.1 200 OK\r\n"
		response = response .. "Content-Disposition: attachment; filename=" .. file_to_download .. "\r\n"    
		response = response .. "Last-Modified: " .. properties.getlastmodified .. "\r\n"    
		response = response .. "Date: " .. os.date("%a, %d %b %Y %H:%M:%S GMT") .. "\r\n"    
		response = response .. "Server: MyUpload Server\r\n"    
		
		-- If a cookie is provided, include it in the response headers
		if cookie then
			response = response .. "Set-Cookie: " .. cookie .. "\r\n" 
		end
		response = response .. "Content-Length: " .. #file_data .. "\r\n"
		response = response .. "\r\n" -- End of headers
		response = response .. file_data
		client_socket:send(response)             
    else
		local html = html_header("Error") .. 
    	[[
        <p>File not found: ]] ..file_path .. [[ </p>]]  ..  html_footer()	    
		send_response(client_socket, "200 OK", "text/html", html, cookie)   
    end
end

-- Function to parse multipart form-data body
function parse_multipart_form_data(body, boundary)
    local parts = {}
    local pattern = "--" .. boundary .. "\r\n(.-)\r\n\r\n(.-)\r\n--"
    for header, data in body:gmatch(pattern) do
        local filename = header:match('filename="(.-)"')
        if filename then
            parts[filename] = data
        end
    end
    return parts
end

-- Return boolean of whether example has a file extension found in extList
function extMatch (extList, filename)
  for _, extension in pairs(extList) do
    if filename:lower():match("%." .. extension:lower() .. "$") then
      return true
    end
  end
  return false
end

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
	i = i + 1
	if a[i] == nil then return nil
	else return a[i], t[a[i]]
	end
  end
  return iter
end


-- Function to base64 encode the username and password for Authentication
local function base64encode(username, password)
    local auth_string = username .. ":" .. password
    return mime.b64(auth_string)
end

-- Function to handle the login POST request
function handle_login(client_socket, body)
    -- print('body=',body)
		-- Parse the query string part of the URL 
		-- examples
		--  url query:  ?dir=/root/folder&ebook=my.epub
		--      query_params.dir will contain /root/folder
		--      query_params.ebook will contain my.epub
		--  url query:  ?dir=/root/folder&ebook=my.epub
		--      query_params.dir will contain /root/folder
		--      query_params.ebook will contain my.epub	
	local query_params = url_path_parsing(body)
	local username = url.unescape(query_params.username)
	--print('username='..username)
	local password = url.unescape(query_params.password)
	--print('password='..password)
	local html 
	if validate_password(username, password) == true  then
        -- If login is successful
        html =  html_header("Login succesfully") ..  
        [[<p>Welcome to the Upload server</p>    
        ]] .. html_footer()
		-- Create Authentication cookie
		local auth = base64encode(username, password)
		cookie = "UploadsAuthorized=" .. auth .. "\r\n"
		send_response(client_socket, "200 OK", "text/html", html, cookie)    
    else
        -- If login fails
        html =  html_header("Login Failed") ..  
        [[<p>No access to the Upload server</p>    
        ]] .. html_footer()        cookie = nil
        send_response(client_socket, "401 Unauthorized", "text/html", html, cookie)
    end
end


-- Parse all cookies and a specific cookie value from a from the "Cookie" header 
function parse_cookies(headers, cookie_name)
    local cookies = {}
    local specific_cookie_value = nil
    if headers["cookie"] then
        for cookie in headers["cookie"]:gmatch("([^;]+)") do
            local key, value = cookie:match("([^=]+)=([^;]+)")
			if key and value then
				--print ('cookie key=',key, 'value=', value)
				cookies[key] = value
				
				if cookie_name then
					if key == cookie_name then
					   specific_cookie_value = value
					end
			    end					   
			end
        end
    end
    return cookies, specific_cookie_value
end

function validate_password(username, password)   
    local user = username
    local pass = password
    --print('Received - user: ' .. username ..', pass: ' .. password)
    local Upload_parms = G_reader_settings:readSetting("Upload_parms")
	local Upload_username, Upload_password
	if Upload_parms then
		Upload_username =  tostring(Upload_parms["username"]) 
		Upload_password =  tostring(Upload_parms["password"])
		username = nil
		password = nil
	end
	--if pass then print('Received - user: ' .. user ..', pass: ' .. pass) end
    --print('Stored - user: ' .. Upload_username ..', pass: ' .. Upload_password)
	--if password then print('Memory - user: ' .. username ..', pass: ' .. password) end
    return tostring(user) == tostring(Upload_username) and tostring(pass) == tostring(Upload_password)
end

-- Function to check authentication
function is_authorized(headers)
    local is_authorized_result = false  -- default false!
    
    all_cookies, specific_cookie_value = parse_cookies(headers, 'UploadsAuthorized') 
    if not specific_cookie_value then  -- no cookie value has been received
        return is_authorized_result
    end  
    local decoded_credentials = mime.unb64(specific_cookie_value)
	if not decoded_credentials then  -- a wrong encoded cookie value has been received
        return is_authorized_result
    end	    
	--print('decoded_credentials:' , decoded_credentials)
	if not username then -- no username value has been received in the decoded cookie
        return is_authorized_result
    end	 	
	if not password then -- no password value has been received in the decoded cookie
        return is_authorized_result
    end	 	
	local username, password = string.match(decoded_credentials, "(%S+):(%S+)")
	--print('specific_cookie_value: ', specific_cookie_value)
	is_authorized_result = validate_password(username, password)  -- a validated result has been received might be true or false  
    return is_authorized_result  
end


-- Helper functions to handle file uploads
local function url_decode(str)
  return url.unescape(str)
end
-- Helper functions to handle file downloads
local function url_encode(str)
  return url.escape(str)
end

-- Function to handle file upload
local function handle_upload(file_data)
    local filename = file_data.filename
    local file_content = file_data.content
    if not is_allowed_extension(filename) then
	    client_socket:send("HTTP/1.1 400 Bad Request\r\n\r\nMissing boundary in Content-Type.\r\n")    
		local html = html_header("Upload of file") ..    
        [[<p>Invalid file extension. Only EPUB, ZIP, MOBI, PDF, AZW3 are allowed.</p>]] .. filename .. 
        [[<a href="/home">Back to Home</a>
         ]] .. html_footer()	 
		send_response(client_socket, "200 OK", "text/html", html, cookie)   
        return 
    end
    -- Save the uploaded file (handle spaces in the filename)
    local file = io.open('"' .. ebooks_dir_to_list .. url_decode(filename) ..'"', "wb")
    if file then
        file:write(file_content)
        file:close()
		local html = html_header("Upload of file") ..
		[[<p>File uploaded successfully: ]] .. filename .. 
        [[</p><a href="/home">Back to Home</a>
        ]] .. html_footer()	    
		send_response(client_socket, "200 OK", "text/html", html, cookie) 
		return  
    else
 		local html = html_header("Upload of file") ..
		[[<p>File uploaded failed: ]] .. filename .. 
        [[</p><a href="/home">Back to Home</a>
        ]] .. html_footer()	    
		send_response(client_socket, "200 OK", "text/html", html, cookie)   
        return
    end
end

function read_posted_body(client_socket, headers)
    -- Read the body of the POST request
    -- Get the content length, which tells us how much data to expect
    local content_length = tonumber(headers["content-length"]) or 0
    local body = ""   
    -- Read the full body, either by chunks or until content-length is reached
    local remaining = content_length
    while remaining > 0 do
      local chunk_size = math.min(1024, remaining)
      local chunk, err = client_socket:receive(chunk_size)
      if not chunk then
    	local html = html_header("Error") .. 
    	[[
        <p>Unsolvable error occured when processing data (part of body) send by browser: ]] .. err .. 
        [[</p>]] ..  html_footer() 	    
		send_response(client_socket, "200 OK", "text/html", html, cookie)       
        break
      end
      body = body .. chunk
      remaining = remaining - #chunk
    end    
	if not body then
    	local html = html_header("Error") .. 
    	[[
        <p>Unsolvable error occured when processing data (body) send by browser: ]] .. err .. 
        [[</p>]]  ..  html_footer()	    
		send_response(client_socket, "200 OK", "text/html", html, cookie)   
		client_socket:close()
		return
	end
	return body
end

function url_path_parsing(path)
		 -- Parse the URL into components
		local parsed_url = url.parse(path)
		-- Function to parse query string into a table
		local function parse_query(query)
			local params = {}
			for key, value in string.gmatch(query, "([^&=?]-)=([^&=?]+)") do
				params[key] = value
			end
			return params
		end
		-- Parse the query string part of the URL
		local query_params = parse_query(parsed_url.query)
		return query_params
end

-- Function to split the string into a table
function split(files_list, delimiter)
    local result = {}
    for match in string.gmatch(file_list, "[^"..delimiter.."]+") do
        table.insert(result, match)
    end
    return result
end


-- HTTP server logic
function handle_request(client_socket)
    local request = client_socket:receive("*l")
    if not request then return end
        -- Parse URL
    local method, path = request:match("([A-Z]+) (/[^ ]*)")  
    -- Read the rest of the request headers
    local headers = {}
    while true do
        local line = client_socket:receive("*l")
        if not line or line == "" then
            break
        end
        local k, v = line:match("^(.-): (.+)$")       
        if k and v then
            headers[k:lower()] = v        
        end 
    end

   -- Handle the login page and POST request for login
    if method == "GET" and path == "/" or method == "GET" and path == "/login" or  method == "GET" and path == "" then
       -- Show login page     
			local html = 
			[[
        <!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f2f2f2; }
        .container { max-width: 400px; margin: auto; padding: 20px; background-color: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        input { width: 99%; padding: 5px; margin: 5px 0; }
        input[type=checkbox] { width: 20%; padding: 5px; margin: 5px 5px 15px 5px; }
        button { padding: 10px; width: 99%; background-color: #4CAF50; color: white; border: none; cursor: pointer; }
        button:hover { background-color: #45a049; }
        .error { color: red; font-size: 14px; margin: 10px 0; }
        .show-password { margin-top: 10px; text-align:left }
    </style>
</head>
<body>
    <div class="container">
        <h2>Login</h2>
        <form action="/login" method="POST">
            <div class="error" id="error-message"></div>
            <label for="username">Username</label>
            <input type="text" id="username" name="username" required>
            <label for="password">Password</label>
            <input type="password" id="password" name="password" required>
            <label class="show-password">
                <input type="checkbox" name="show-password"> Show Password
            </label>
            <button type="submit">Login</button>
        </form>
    </div>

    <script>
        // Show/Hide password using the checkbox
        const passwordField = document.getElementById("password");
        const showPasswordCheckbox = document.querySelector("input[name='show-password']");
        showPasswordCheckbox.addEventListener('change', function() {
            passwordField.type = this.checked ? "text" : "password";
        });
    </script>
</body>
</html>]] 
            -- Show login page
			send_response(client_socket, "200 OK", "text/html", html)
			
    -- Handle POST request for login validation
    elseif method == "POST" and path == "/login" then   
		-- Process the POST request for login
		local content_type = headers["content-type"]		
		-- Read the body of the POST request
		local body = read_posted_body(client_socket, headers)
		-- Parse the query string part of the URL 
		-- POST example query does NOT starts with ?, so we add it to the body!
		--  url query:  username=admin&password=1234&show-password=on"
		--      query_params.username will contain admin
		--      query_params.password will contain 1234
		--      query_params.show-password will contain on
		body = '?' .. body -- we add ? to simulate the GET request!
		handle_login(client_socket, body)
		 
    -- Handle GET request for home page
	 elseif method == 'GET' and path == "/logout"  then
	   if is_authorized(headers) then   
		   local html = html_header("Logout") ..
			[[
			<p>Bye to the Upload Server. You are now logged out.</p>
			<ul>
				<li><a href="/login">Log in again</a></li>
			</ul>
			]] .. html_footer() 
			cookie = "UploadsAuthorized=;expires=Thu, 01 Jan 1970 00:00:00 GMT;"	
			send_response(client_socket, "200 OK", "text/html", html, cookie)  
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
      end  
        
	 elseif method == 'GET' and path == "/stop"  then
	   if is_authorized(headers) then   
		   local html = html_header("Stop") ..
			[[
			<p>The Upload Server has been stopped. You were logged out automatically.</p>
			<ul>
				<li><a href="/login">Log in again</a> is only possible after a new start of the Upload Server! If you click before the Upload Server is running a connection is not possible!</li>
			</ul>
			]] .. html_footer() 
			cookie = "UploadsAuthorized=;expires=Thu, 01 Jan 1970 00:00:00 GMT;"	
			send_response(client_socket, "200 OK", "text/html", html, cookie)  -- first send the stop page the stop server
			browser_forced_shutdown = true -- force shutdown of server 
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end   

    -- Handle GET request for home page
	 elseif method == 'GET' and path == "/home"  then
	   if is_authorized(headers) then   
		   local html = html_header("Home") ..
			[[
			<p>Welcome to the Upload Server. Please choose an action from top menu.</p>
			<table>
				<tr><td align="right"><a href="/upload">Upload eBooks</a></td><td>Upload an eBook into your Home folder you have set on KOReader</td></tr>
				<tr><td align="right"><a href="/clipping_dir">List Clipboard folder</a></td><td>List / download of clipping files from the directory you have set</td></tr>
				<tr><td align="right"><a href="/files">List Home folder</a></td><td>List / download of <b>only files</b> from Home folder</td></tr>            
				<tr><td align="right"><a href="/folders">List</a> or <a href="/folders_paging">Page</a> ebooks in folders</td><td>List or Page &amp; download of ebooks per folder e.g. per author</td></tr>
				<tr><td align="right"><a href="/flat_view_files">List</a> or <a href="/flat_view_files_paging">Page</a> All eBooks</a></td><td>Flat view list or Page &amp; download ebooks sorted by folder/content</td></tr>			
				<tr><td align="right" colspan="100%">&nbsp;</td></tr>			
				<tr><td align="right"><a href="/stop">Stop</a></td><td>Stop the Upload Server on the device immediately.You will be logged out automatically.</td></tr>			
			</table>
			]] .. html_footer()  
			send_response(client_socket, "200 OK", "text/html", html, cookie)  
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end   
      
    -- CHECK THIS FUNCTION 
    elseif path == "/file" then
      if is_authorized(headers) then 
		   local html = html_header("Download of file Ok") ..
			[[
			<p>File downloaded</p>
			]] .. html_footer()  
			send_response(client_socket, "200 OK", "text/html", html, cookie)  
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end       
      
     -- Handle GET request for home page
	 elseif method == 'GET' and path == "/upload"  then
	   if is_authorized(headers) then   
		 if ebooks_dir_to_list then  -- test  value
			local comment
		    if ebooks_dir_to_list == "." then
				comment = " (Note that the KOReader Home folder is not set!)"
			else
				comment = " (KOReader Home folder)"	
		   end	 
		   local html = html_header("Upload eBook") ..
			[[
			<p>Upload File to homedir: ]] ..ebooks_dir_to_list .. comment ..[[</p>
			<p>
				<form onsubmit="return validateFile()" action='/upload' method='POST' enctype='multipart/form-data'>
				Select file: <input type='file' id="fileUpload" name='file' multiple  accept=".epub,.azw3,.mobi,.pdf,.txt,.cbz" required/><br>
				<input type='submit' value='Upload'></form>
			</p>
			]] .. html_footer() 
			send_response(client_socket, "200 OK", "text/html", html, cookie)  
		else
		    html = html_header("Upload eBook") ..   
		    [[<p>No Home folder is specified in Koreader</p>
		      <p>To specify the Home folder go to the KOReader 'Cabinet icon" menu &gt; Settings &gt; Home folder settings &gt; Set home folder.</p>]] .. html_footer()
		    send_response(client_socket, "200 OK", "text/html", html, cookie)  
		end		
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end  
              
    -- Handle GET request for file listing      
    elseif method == 'GET' and path == "/clipping_dir" then 
      if is_authorized(headers) then   
        if clipping_dir ~= 'None' then  
			local files = list_files(clipping_dir)		
			keys = {}
			for key, _ in pairs(files) do
				table.insert(keys, key)
			end
			-- sort the folders
			table.sort(keys, function(keyLhs, keyRhs) return files[keyLhs] < files[keyRhs] end)
			-- construct the html page
			html = html_header("Files in folder") ..   
			"<table><thead><tr><th>" .. clipping_dir .. "</th></tr></thead><table>"
			for _, file in ipairs(files) do
				html = html .. "<tr><td><a href='/download?file=" ..  url.escape(clipping_dir .. '/' ..file) .. "' download='" 
					  .. file ..  "'>" .. file .. "</a></td><tr>"
			end
			html = html .. "</table>" .. html_footer()
			send_response(client_socket, "200 OK", "text/html", html, cookie)  
		else
		    html = html_header("Files in folder") ..   
		    [[<p>No Export folder for Notes and Highlights is specified in Koreader</p>
		      <p>To specify this folder go to the KOReader 'Wrench/Screwdriver icon" menu &gt; Export Highlights &gt; Choose Export folder.</p>]] .. html_footer()
		    send_response(client_socket, "200 OK", "text/html", html, cookie)  
		end
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end  

			  
    -- Handle GET request for indir 	(selected on folders list)   
	elseif method == 'GET' and path:match("(/indir)/?(.+)") then 
	  if is_authorized(headers) then 
		if string.len(path) ~= 0 then -- test nil value
			-- Parse the query string part of the URL 
			-- GET example query starts with ? !
			--  url query:  ?dir=/root/folder&ebook=my.epub
			--      query_params.dir will contain /root/folder
			--      query_params.ebook will contain my.epub
			local query_params = url_path_parsing(path)
			-- Print the value of the 'dir' parameter
			local dir_to_list = url.unescape(query_params.dir) or "."
			local files = list_files(dir_to_list)
			html = html_header("Files in folder") ..   
			"<table><thead><tr><th>" .. dir_to_list .. "</th></tr></thead><table>"
			for _, file in ipairs(files) do
				html = html .. "<tr><td><a href='/download?file=" ..  url.escape(dir_to_list .. '/' ..file) .. "' download='" 
					  .. file ..  "'>" .. file .. "</a></td><tr>"
			end
			html = html .. "</table>" .. html_footer()
			send_response(client_socket, "200 OK", "text/html", html, cookie)   
		else
		    html = html_header("Files in folder") ..   
		    [[<p>No folder was specified in the request. Retry again.</p>]] .. html_footer()
		    send_response(client_socket, "200 OK", "text/html", html, cookie)  
		end			 
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end  
 
    -- Handle GET request for file listing      
    elseif method == 'GET' and path == "/files" then 
      if is_authorized(headers) then   
		local files = list_files(ebooks_dir_to_list)
		local comment
		if ebooks_dir_to_list == "." then
			comment = " (KOreader Home folder is not set!)"
		else
			comment = " (KOReader Home folder)"
		end
        html = html_header("Files in Home folder") ..   
        "<table><thead><tr><th>" .. ebooks_dir_to_list .. comment .. "</th></tr></thead><table>"
        for _, file in ipairs(files) do
          local href = ebooks_dir_to_list .. '/' .. file
          html = html .. '<tr><td><a href="/download?file=' .. href .. '" download="' .. file ..  '">' .. file .. '</a></td></tr>'

          --  html = html .. "<tr><td><a href='/download?file=" ..  url.escape(ebooks_dir_to_list) .. '/' ..url.escape(file) .. "' download='" 
		--		  .. file ..  "'>" .. file .. "</a></td><tr>"
        end
        html = html .. "</table>" .. html_footer()
        send_response(client_socket, "200 OK", "text/html", html, cookie) 
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end  
 
  
    -- Handle GET request for flat file view listing      
    elseif method == 'GET' and path == "/flat_view_files_paging" then 
      if is_authorized(headers) then   
		local files = io.popen('find "'.. ebooks_dir_to_list  .. '/' .. '" -maxdepth 10 -type f  -name "*.epub" -o -name "*.pdf" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.docx" -o -name "*.cbz" -o -name "*.txt" ! -name "*.opf" ! -name "*.jpg" ! -name "*.gz" ! -name "*.zip" ! -name "*.tar" ') -- on linux
		local file_list = files:read("*a")
		files:close()
		-- print('file_list = ',file_list)
		-- Function to split the string into a table
		local function split(files_list, delimiter)
			local result = {}
			for match in string.gmatch(file_list, "[^"..delimiter.."]+") do
				table.insert(result, match)
			end
			return result
		end
		-- Split the files_list string into a table of substrings
		local splitted_files = split(files_list, "\n")
		--print('#splitted_files=', #splitted_files)
		-- Remove the last empty entry from the table
		--table.remove(splitted_files, splitted_files)
		-- Function to print the table
		--local function print_table(tbl)
		--	for _, v in ipairs(tbl) do
		--		print(v)
		--	end
		--end
		-- Sort the table in ascending order
		local ascending_files = {table.unpack(splitted_files)}
		table.sort(ascending_files)
		-- Sort the table in descending order (by reversing the order)
		--local descending_files = {table.unpack(ascending_files)}
		--table.sort(descending_files, function(a, b) return a > b end)
		-- Print the ascending sorted table
		--print("Ascending Order:")
		--print_table(ascending_files)
		-- Print the descending sorted table
		--print("\nDescending Order:")
		--print_table(descending_files)
        local html = html_header("All eBooks in Home folder") ..  
                      html_paging_part1(  "<table><thead><tr><th>" .. ebooks_dir_to_list .. "</th></tr></thead><table>")   
		for _, file in ipairs(ascending_files) do
			--print(line)
			local path, filename, extension = string.match(file, "(.-)([^\\/]-%.?([^%.\\/]*))$")
			local file_path = ebooks_dir_to_list .. "/" .. filename
			--print('file_path1:', file_path, ' filename:', filename)		
			if filename then
			  html = html .. "<tr><td><a href='/download?file=" .. url.escape(file) .. "' download='" .. filename ..  "'>" .. filename .. "</a></td></tr>"
			end
		end
        html = html .. html_paging_part2() .. html_footer()
        --print(html)
        send_response(client_socket, "200 OK", "text/html", html, cookie) 
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end  
 
 
 
 
    -- Handle GET request for flat file view listing      
    elseif method == 'GET' and path == "/flat_view_files" then 
      if is_authorized(headers) then   
		local files = io.popen('find "'.. ebooks_dir_to_list  .. '/' .. '" -maxdepth 10 -type f  -name "*.epub" -o -name "*.pdf" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.docx" -o -name "*.cbz" -o -name "*.txt" ! -name "*.opf" ! -name "*.jpg" ! -name "*.gz" ! -name "*.zip" ! -name "*.tar" ') -- on linux
		local file_list = files:read("*a")
		files:close()
		-- print('file_list = ',file_list)
		-- Function to split the string into a table
		local function split(files_list, delimiter)
			local result = {}
			for match in string.gmatch(file_list, "[^"..delimiter.."]+") do
				table.insert(result, match)
			end
			return result
		end
		-- Split the files_list string into a table of substrings
		local splitted_files = split(files_list, "\n")
		--print('#splitted_files=', #splitted_files)
		-- Remove the last empty entry from the table
		--table.remove(splitted_files, splitted_files)
		-- Function to print the table
		--local function print_table(tbl)
		--	for _, v in ipairs(tbl) do
		--		print(v)
		--	end
		--end
		-- Sort the table in ascending order
		local ascending_files = {table.unpack(splitted_files)}
		table.sort(ascending_files)
		-- Sort the table in descending order (by reversing the order)
		--local descending_files = {table.unpack(ascending_files)}
		--table.sort(descending_files, function(a, b) return a > b end)
		-- Print the ascending sorted table
		--print("Ascending Order:")
		--print_table(ascending_files)
		-- Print the descending sorted table
		--print("\nDescending Order:")
		--print_table(descending_files)
        html = html_header("All eBooks in Home folder") ..   
        "<table><thead><tr><th>" .. ebooks_dir_to_list .. "</th></tr></thead><table>"
		for _, file in ipairs(ascending_files) do
			--print(line)
			local path, filename, extension = string.match(file, "(.-)([^\\/]-%.?([^%.\\/]*))$")
			local file_path = ebooks_dir_to_list .. "/" .. filename
			--print('file_path1:', file_path, ' filename:', filename)		
			if filename then
			  html = html .. "<tr><td><a href='/download?file=" .. url.escape(file) .. "' download='" .. filename ..  "'>" .. filename .. "</a></td></tr>"
			end
		end
        html = html .. "</table>" .. html_footer()
        send_response(client_socket, "200 OK", "text/html", html, cookie) 
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end  
	  
    -- Handle GET request for folders list  
    elseif method == 'GET' and path == "/folders_paging" then  
	  if is_authorized(headers) then 
        local folders = list_folders(ebooks_dir_to_list)       
		keys = {}
		for key, _ in pairs(folders) do
			table.insert(keys, key)
		end
		-- sort the folders
		table.sort(keys, function(keyLhs, keyRhs) return folders[keyLhs] < folders[keyRhs] end)
		-- construct the html page	  
        html = html_header("eBooks in (sub)folders") ..  
               html_paging_part1("<thead><tr><th>eBook</th><th>Located in folder under " .. ebooks_dir_to_list .. "</th></tr></thead>" )   

        local ebooks_dir_to_list_length = string.len(ebooks_dir_to_list)  
        for _, folder in ipairs(folders) do
			local folder_length =  string.len(folder)
			local path, file, extension = string.match(folder, "(.-)([^\\/]-%.?([^%.\\/]*))$")	
			local file_length =  string.len(file)
			-- Data declarations of allow file extensions to be Viewed and/or Downloadable
			local extentions = {"epub", "pdf", "azw3", "mobi", "docx", "txt", "cbz", "json", "sqlite"}
			if extMatch(extentions, file) == true then
			 -- the first / of the folder is not shown so stripped
				location_display = string.sub(folder, ebooks_dir_to_list_length + 2, folder_length - file_length - 1)
				location_href =  string.sub(folder, 0, folder_length - file_length - 1)			    
				if location_dir == "" then
					location_dir = '.'
				end  
				html = html .. "<tr><td><a href='/download?file=" ..  url.escape(folder) .. "' download='" 
				  .. file ..  "'>" .. file .. "</a></td><td>"  ..location_display  .. "<a href='/indir?dir=" ..   url.escape(location_href) .. "'> List</a></td></tr>"
			end 
        end
        html = html ..  html_paging_part2()  .. html_footer()
		send_response(client_socket, "200 OK", "text/html", html, cookie)          
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end 

    -- Handle GET request for folders list  
    elseif method == 'GET' and path == "/folders" then  
	  if is_authorized(headers) then 
        local folders = list_folders(ebooks_dir_to_list)       
		keys = {}
		for key, _ in pairs(folders) do
			table.insert(keys, key)
		end
		-- sort the folders
		table.sort(keys, function(keyLhs, keyRhs) return folders[keyLhs] < folders[keyRhs] end)
		-- construct the html page	  
        html = html_header("eBooks in (sub)folders") ..   
        "<div><table><thead><tr><th>eBook</th><th>Located in folder under "..ebooks_dir_to_list.."</th></tr></thead>"
        local ebooks_dir_to_list_length = string.len(ebooks_dir_to_list)  
        for _, folder in ipairs(folders) do
			local folder_length =  string.len(folder)
			local path, file, extension = string.match(folder, "(.-)([^\\/]-%.?([^%.\\/]*))$")	
			local file_length =  string.len(file)
			-- Data declarations of allow file extensions to be Viewed and/or Downloadable
			local extentions = {"epub", "pdf", "azw3", "mobi", "docx", "txt", "cbz", "json", "sqlite"}
			if extMatch(extentions, file) == true then
			 -- the first / of the folder is not shown so stripped
				location_display = string.sub(folder, ebooks_dir_to_list_length + 2, folder_length - file_length - 1)
				location_href =  string.sub(folder, 0, folder_length - file_length - 1)			    
				if location_dir == "" then
					location_dir = '.'
				end  
				html = html .. "<tr><td><a href='/download?file=" ..  url.escape(folder) .. "' download='" 
				  .. file ..  "'>" .. file .. "</a></td><td>"  ..location_display  .. "<a href='/indir?dir=" ..   url.escape(location_href) .. "'> List</a></td></tr>"
			end 
        end
        html = html .. "</table></div>" .. html_footer()
		send_response(client_socket, "200 OK", "text/html", html, cookie)          
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end 



    -- Handle GET requests for download of file
    elseif method == 'GET' and path:match("/download%?file=([^ ]+)") then  -- OR THIS elseif request:match("GET /download") then  
      if is_authorized(headers) then 
        local file_name = request:match("GET /download%?file=([^ ]+)")
		-- file_name = '"'..file_name..'"'
        if file_name then
            file_name = url.unescape(file_name)
            download_file(file_name, client_socket)
        else
		    local html = html_header("Bad request.") .. 
		    [[
			<p>Invalid file request</p> 
			]]  ..  html_footer()
			send_response(client_socket, "400 Bad Request", "text/html", html, cookie)					
			return	
        end
      else -- Authentication failed, redirect to login page       
        send_response_location(client_socket, "302 Found", "/login", cookie) 
	  end 
			
	  -- Handle POST requests for upload of file			
	  elseif method == 'POST' and path == "/upload" then 
		  if is_authorized(headers) then  
			-- Process the POST request for file uploads
			-- Read the body of the POST request
			local content_type = headers["content-type"]
			local boundary = content_type and content_type:match("boundary=([%w-]+)")
			
			if not boundary then
			  local html = html_header("Bad request.") .. 
				  [[
					<p>Missing boundary in Content-Type. Request is not properly formatted!</p> 
					]]  ..  html_footer()
				    send_response(client_socket, "400 Bad Request", "text/html", html, cookie)					
					return			
			end		
			-- Read the body of the POST request
			local body = read_posted_body(client_socket, headers)
			-- Process the multipart form data
			local parts = {}
			local boundary_pattern = "--" .. boundary
			local end_boundary = "--" .. boundary .. "--"
			local start_index = 1	
			local all_html =  html_header("File upload results") .. "<table>" 			
			
			-- Loop through and extract the multipart parts
			while true do
			  local start_pos, end_pos = body:find(boundary_pattern, start_index)
			  if not start_pos then break end  -- No more parts	  
			  local part = body:sub(start_pos + #boundary_pattern, body:find("\r\n\r\n", start_pos))
			  -- Check for file content disposition
			  local filename = part:match('filename="(.-)"')
			  local content_disposition = part:match("Content-Disposition:*.name=\"(.-)\"; filename=\"(.-)\"")
			  if content_disposition then
				  filename = content_disposition
			  end
			  -- print('filename = ', filename)
			  if filename and filename ~= "" then
				-- Data declarations of allow file extensions to be uploaded
				local extentions = {"epub", "pdf", "azw3", "mobi", "docx", "txt", "cbz"}
				local path, file, extension = string.match(filename, "(.-)([^\\/]-%.?([^%.\\/]*))$")       
				local file_hdrs_data_ = body:sub(end_pos + 4, body:find(end_boundary , end_pos ) - 1) -- this is inclusive the headers 			
				--[[- IMPORTANT we need to strip these lines!!! form the file_hrs_data
				Content-Disposition: form-data; name="file"; filename="My World - T. Writer (57).epub"
				Content-Type: application/epub+zip
				--]]	
				
				local blank_line_index = file_hdrs_data_:find("\r\n\r\n")
				local real_file_content = file_hdrs_data_:sub(blank_line_index+4)
				-- Save the file
				if save_file(real_file_content, filename) and extMatch(extentions, file) == true then
				  local html = 
				  [[
					<tr><td>]] .. filename .. [[</td><td>File uploaded successfully</td></tr> 
					]]  
					all_html = all_html .. html
				  --send_response(client_socket, "200 OK", "text/html", html, cookie)
				else
					local html = 
					[[
					<tr><td>]]  .. filename .. [[</td><td>Failed to save file. Extension not supported?</td></tr> 
					]]  	
					all_html = all_html .. html				
				  --send_response(client_socket, "500 Internal Server Error", "text/html", html, cookie)
				end					 
			  end
			  start_index = end_pos + 1
			end
			 all_html = all_html .. "</table>"  ..  html_footer()	
			send_response(client_socket, "200 OK", "text/html", all_html, cookie)
		  else
			local html = html_header("Error occured") ..  
				[[
				<p>Invalid request! Retry another function/request.</p>    	
				]] .. "</table>"  ..  html_footer()	 			
			    send_response(client_socket, "400 Bad Request", "text/html", html, cookie)	
		  end	  
		end
  client_socket:close()
end

function save_file(file_data, filename)
  if filename and file_data then
	  local file_path = upload_dir .. "/" .. filename
	  file_path = url_decode(file_path)
	  local file, err = io.open(file_path, "wb")
	  if not file then
		print("Error opening file for writing: " .. err)
		return false
	  end
	  file:write(file_data)
	  file:close()
	  return true
  else
	return false
  end
end
-- --------------------------------------------------------------------------------------------------

lastTimeProcessed = os.clock()

function IsTimeToProcess(currentTime)
    span = currentTime - lastTimeProcessed
    if span >= 1 then
        lastTimeProcessed = currentTime
        return true
    end
    return false
end

function is_ipv4( frame )
    local s = frame.args[1] or ''
    s = s:gsub("/[0-9]$", ""):gsub("/[12][0-9]$", ""):gsub("/[3][0-2]$", "")  
    if not s:find("^%d+%.%d+%.%d+%.%d+$") then
        return nil
    end   
    for substr in s:gmatch("(%d+)") do
        if not substr:find("^[1-9]?[0-9]$")
                and not substr:find("^1[0-9][0-9]$")
                and not substr:find( "^2[0-4][0-9]$")
                and not substr:find("^25[0-5]$") then
            return nil
        end
    end  
    return '1'
end

-- Start HTTP server-- --------------------------------------------------------------------------------------------------
function start_server()
	browser_forced_shutdown = false
    if server_running then
        print("Server is already running.")
        return
    end	
    
    -- Make a hole in the Kindle's firewall
    if Device:isKindle() then
        os.execute(string.format("%s %s %s",
            "iptables -A INPUT -p tcp --dport", port,
            "-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"))
        os.execute(string.format("%s %s %s",
            "iptables -A OUTPUT -p tcp --sport", port,
            "-m conntrack --ctstate ESTABLISHED -j ACCEPT"))
    end
    
    server_socket = assert(socket.bind('*', port))
    server_socket:settimeout(0)  -- Non-blocking
    print("Upload server started to run on port " .. tostring(port) .. ' for ' .. tostring(seconds_runtime) ..  ' seconds.')
    local date = os.date('*t')
	local time = os.date("*t")
	print('Started at: ', os.date("%A, %m %B %Y | "), ("%02d:%02d:%02d"):format(time.hour, time.min, time.sec))
    server_running = true  
	function wait(s)
	  local lastvar
	  for i=1, s do
			lastvar = os.time()
			while lastvar == os.time() do
				--print(lastvar)
				local client_socket, err = server_socket:accept()
				if client_socket then
					client_socket:settimeout(2)
					handle_request(client_socket)
					client_socket:close()
				end			
			end
		 if browser_forced_shutdown == true then
		   break
		 end
	  end
	end
	wait(seconds_runtime) -- in seconds the the Upload Server will stop automatically to save battery
	if server_socket then
		-- Close the hole in the Kindle's firewall
		if Device:isKindle() then
			os.execute(string.format("%s %s %s",
				"iptables -D INPUT -p tcp --dport", port,
				"-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT"))
			os.execute(string.format("%s %s %s",
				"iptables -D OUTPUT -p tcp --sport", port,
				"-m conntrack --ctstate ESTABLISHED -j ACCEPT"))
		end	
		server_running = false
		server_socket:close()
		date = os.date('*t')
		time = os.date("*t")
		print('Stopped at: ', os.date("%A, %m %B %Y | "), ("%02d:%02d:%02d"):format(time.hour, time.min, time.sec))
		print('Upload server has been stopped listing at http://' .. tostring(ip) .. ':' .. tostring(port) )
	end
 -- The loop WITHOUT using a Timer looks look this	  
 --   while server_running do
 --       local client_socket, err = server_socket:accept()
 --       if client_socket then
 --           client_socket:settimeout(2)
 --           handle_request(client_socket)
 --           client_socket:close()
 --       end
 --   end
end

-- Stop the server
local function stop_server()
    if not server_running then
        print("Server is not running.")
        return
    end
    server_running = false
    if server_socket then
        server_socket:close()
    end
    print("Upload server has been stopped.")
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
        text = _("Upload Server"),
        -- sorting_hint = "more_tools",
        sub_item_table = { 
		    {  
                text = "Is device via Wifi connected to LAN? Then start Upload server", 
                enabled=false,
                separator=false,
              }, 
              {
                text = "Menu locked? Upload is running!",
                enabled=false,
                separator=false,
              }, 
				{  
                text = "Login at http://" .. Upload_parms_ip_address .. ":" ..  tostring(port), 
                enabled=false,
                separator=true,
              },               
				{  
                text = "QRcode for login" , 
                enabled=true,
                separator=true,
				callback = function()
					UIManager:show(QRMessage:new{
						text = "http://" .. Upload_parms_ip_address .. ":" ..  tostring(port),
						width = Device.screen:getWidth(),
						height = Device.screen:getHeight()
					})
				end,         
              },                   
			{   text = _("Start Upload server. Stops after " .. tostring(seconds_runtime) .."s" ),
                keep_menu_open = true,
                callback = function()  		
					-- start the server 
					-- MyUpload:RunningServer() -- appears too late after process has been ending, how to put  delay before the start_server()???
					start_server()	
					MyUpload:AutoStopServer()							    			
                end,
            },       
		   {	   
				text = _("Settings"),	
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
										text = Upload_parms_ip_address,
										input_type = "string",
										hint = _("nil or 127.0.0.1? Set to IP address of ereader!"),
									},						
									{  
										text = Upload_parms_port,
										input_type = "number",
										hint = _("Port number (default 8080)"),
									},
									{
										text = Upload_seconds_run,
										input_type = "number",
										hint = _("Runtime range 60-900 seconds (default 60)."),
									},	
									{
										text = Upload_username,
										input_type = "string",
										hint = _("Username for login into Upload server"),
									},	
									{
										text = Upload_password,
										input_type = "string",
										hint = _("password"),
									},							
								},
								buttons =  {
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
													MyUpload:onUpdateUploadSettings()
													local fields = url_dialog:getFields()
													if not fields[1] ~= "" then
														local ip_address = tonumber(fields[1])
														if not ip_address then
															 --default ip_address
															 ip_address = '127.0.0.1'												
														elseif not is_ipv4(ip_address)  then
															 ip_address = '127.0.0.1'
														end																							
														local new_port = tonumber(fields[2])
														if not new_port or new_port < 1 or new_port > 65355 then
															--default port
															 new_port = 8080
														end
														local new_seconds_runtime = tonumber(fields[3])
														if not new_seconds_runtime or new_seconds_runtime < 30 or new_seconds_runtime > 900 then
															--default port
															 new_seconds_runtime = 60
														end	
														local new_username = tonumber(fields[4])
														if not new_username or new_username == " "  then
															--default new_username
															 new_username = 'admin'
														end													
														local new_password = tonumber(fields[5])
														if not new_password or new_password == " "  then
															--default new_password
															 new_password = '1234'
														end	
																																										
														G_reader_settings:saveSetting("Upload_parms", {ip_address = tostring(ip_address), port = tonumber(new_port), seconds_runtime = tonumber(new_seconds_runtime), username = tostring(new_username), password = tostring(new_password) })
														-- after save make these values the actual ones
														--port = tonumber(new_port)
														--seconds_runtime = tonumber(new_seconds_runtime)
														--username = tostring(new_username)
														--password = tostring(new_password)
													end
													UIManager:close(url_dialog)
													if touchmenu_instance then touchmenu_instance:updateItems() end
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

function MyUpload:RunningServer()
    local popup = InfoMessage:new{
        text = _("Upload Server is now running and will stop automatically"),
    }
    UIManager:show(popup)
end

function MyUpload:AutoStopServer()
    local text_part = 'automatically'
	if browser_forced_shutdown == true then
		text_part = 'manually' 
	end
    local popup = InfoMessage:new{
        text = _("Upload Server has been stopped " .. text_part ..". You may close menu or start Upload server again"),
    }
    UIManager:show(popup)
end

function MyUpload:onWifiIsOff()
    local popup = InfoMessage:new{
        text = _("Switch Wifi ON before starting Upload!"),
    }
    UIManager:show(popup)
end

function MyUpload:onUpdateUploadSettings()
    local popup = InfoMessage:new{
        text = _("Now restart KOReader for changes to take effect!"),
    }
    UIManager:show(popup)
end

function check_socket()
	-- to get your IP address
	local s = socket.udp()
	local result = s:setpeername("pool.ntp.org",80) -- accesses a Dutch time server
	if not result then
	  s:setpeername("north-america.pool.ntp.org",80)-- accesses a North America time server
	end
	local ip, lport, ip_type = s:getsockname() -- The method returns a string with local IP address, a number with the local port, and a string with the family ("inet" or "inet6"). In case of error, the method returns nil.
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
	-- Default Configuration
	-- Default Upload Configuration
	local default_ip_address = "*"
	local default_port = 8080
	local default_username = "admin"
	local default_password = "1234"
	local default_seconds_runtime = 60  -- standard is 1 minute
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
