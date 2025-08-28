local socket = require("socket")
local os = require("os")
local url = require("socket.url")
local lfs = require("libs/libkoreader-lfs")
local mime = require("mime")
local file_utils = require("bookdrop/file_utils")
local auth = require("bookdrop/auth")
local html = require("bookdrop/html_templates")
local DEBUG = require("dbg")
local logger = require("logger")

local M = {}

local function send_response(client, status, content_type, body, cookie)
    local response = "HTTP/1.1 " .. status .. "\r\n"
    response = response .. "Content-Type: " .. content_type .. ";\r\n"
    if cookie then
        response = response .. "Set-Cookie: " .. cookie .. ";\r\n"
    end
    response = response .. "Content-Length: " .. #body .. ";\r\n"
    response = response .. "\r\n" .. body
    client:send(response)
end

local function send_response_location(client, status, location, cookie)
    local response = "HTTP/1.1 " .. status .. "\r\n"
    response = response .. "Location: " .. location .. "\r\n"
    if cookie then
        response = response .. "Set-Cookie: " .. cookie .. ";\r\n"
    end
    response = response .. "\r\n"
    client:send(response)
end

local function read_posted_body(client_socket, headers)
    local content_length = tonumber(headers["content-length"]) or 0
    local body = ""
    local remaining = content_length
    while remaining > 0 do
        local chunk_size = math.min(1024, remaining)
        local chunk, err = client_socket:receive(chunk_size)
        if not chunk then break end
        body = body .. chunk
        remaining = remaining - #chunk
    end
    return body
end

local function parse_headers(client_socket)
    local headers = {}
    while true do
        local line = client_socket:receive("*l")
        if not line or line == "" then break end
        local k, v = line:match("^(.-): (.+)$")
        if k and v then
            headers[k:lower()] = v
        end
    end
    return headers
end

local function get_upload_dir(G_reader_settings)
    local ebooks_dir = G_reader_settings:readSetting("home_dir")
    return ebooks_dir or "."
end

local function get_clipping_dir(G_reader_settings)
    local Exporter_parms = G_reader_settings:readSetting("exporter")
    if Exporter_parms and Exporter_parms["clipping_dir"] then
        return tostring(Exporter_parms["clipping_dir"])
    end
    return nil
end

local function url_path_parsing(path)
    local parsed_url = url.parse(path)
    local function parse_query(query)
        local params = {}
        for key, value in string.gmatch(query or "", "([^&=?]-)=([^&=?]+)") do
            params[key] = value
        end
        return params
    end
    return parse_query(parsed_url.query)
end

local function handle_login(client_socket, body, G_reader_settings)
    local query_params = url_path_parsing(body)
    local username = url.unescape(query_params.username)
    local password = url.unescape(query_params.password)
    if auth.validate_password(username, password, G_reader_settings) then
        local auth_cookie = "UploadsAuthorized=" .. mime.b64(username .. ":" .. password)
        -- Redirect to /upload after successful login
        send_response_location(client_socket, "302 Found", "/upload", auth_cookie)
    else
        local html_body = html.header("Login Failed") ..
            [[<div class="msg">No access to the Upload server</div>]] .. html.footer()
        send_response(client_socket, "401 Unauthorized", "text/html", html_body)
    end
end

local function handle_request(client_socket, G_reader_settings)
    local request = client_socket:receive("*l")
    if not request then return end
    local method, path = request:match("([A-Z]+) (/[^ ]*)")
    local headers = parse_headers(client_socket)
    local upload_dir = get_upload_dir(G_reader_settings)
    local clipping_dir = get_clipping_dir(G_reader_settings)
    local cookie = nil

    -- Login page
    if (method == "GET" and (path == "/" or path:match("^/login") or path == "")) then
        local show_logged_out = false
        if path:find('?loggedout=1', 1, true) then show_logged_out = true end
    local page = html.login_page(show_logged_out)
    send_response(client_socket, "200 OK", "text/html", page)
    elseif method == "POST" and path == "/login" then
        local body = read_posted_body(client_socket, headers)
        body = '?' .. body
        handle_login(client_socket, body, G_reader_settings)
    elseif method == "GET" and path == "/logout" then
        if auth.is_authorized(headers, G_reader_settings) then
            cookie = "UploadsAuthorized=;expires=Thu, 01 Jan 1970 00:00:00 GMT;"
            -- send_response(client_socket, "200 OK", "text/html", html_body, cookie)
            -- Redirect to login page with notification
            send_response_location(client_socket, "302 Found", "/login?loggedout=1", cookie)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end
    elseif method == "GET" and path == "/stop" then
        if auth.is_authorized(headers, G_reader_settings) then
            local page = html.shutdown_page()
            cookie = "UploadsAuthorized=;expires=Thu, 01 Jan 1970 00:00:00 GMT;"
            send_response(client_socket, "200 OK", "text/html", page, cookie)
            M.browser_forced_shutdown = true
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- List files in home folder
    elseif method == "GET" and path:match("^/files") then
        if auth.is_authorized(headers, G_reader_settings) then
            -- Parse ?dir=... if present
            local dir = upload_dir
            local qstr = path:match("%?(.+)")
            if qstr then
                for k, v in string.gmatch(qstr, "([^&=?]+)=([^&=?]+)") do
                    if k == "dir" then
                        dir = url.unescape(v)
                        break
                    end
                end
            end
            -- List folders and files in this dir
            local folders = {}
            local files = {}
            for file in lfs.dir(dir) do
                if file ~= "." and file ~= ".." then
                    local full_path = dir .. "/" .. file
                    local mode = lfs.attributes(full_path, "mode")
                    if mode == "directory" then
                        table.insert(folders, file)
                    elseif mode == "file" then
                        table.insert(files, file)
                    end
                end
            end
            table.sort(folders)
            table.sort(files)
            -- Breadcrumb above table
            local home_dir = upload_dir
            local rel_path = dir:gsub("^" .. home_dir, "")
            if rel_path == "" then rel_path = "/" end
            local crumbs = {}
            local path_accum = home_dir
            table.insert(crumbs, string.format('<a href="/files?dir=%s">KOReader Home</a>', url.escape(home_dir)))
            if rel_path ~= "/" then
                for part in rel_path:gmatch("[^/]+") do
                    path_accum = path_accum .. "/" .. part
                    table.insert(crumbs, string.format('<a href="/files?dir=%s">%s</a>', url.escape(path_accum), part))
                end
            end
            local breadcrumb_html = string.format('<nav class="breadcrumb-nav"><span class="breadcrumb">%s</span></nav>', table.concat(crumbs, ' <span class="breadcrumb-sep">&#8250;</span> '))


            local html_body = html.header("Files & Folders") ..
                breadcrumb_html ..
                '<table><thead><tr><th>Name</th></tr></thead><tbody>'
            -- Emoji logic
            local function get_emoji(name, is_folder)
                if is_folder then return '📁' end
                local ext = name:match("%.([^.]+)$")
                if ext then
                    ext = ext:lower()
                    if ext == "epub" or ext == "pdf" or ext == "azw3" or ext == "mobi" or ext == "cbz" then
                        return '📚'
                    end
                end
                return '📄'
            end
            for _, folder in ipairs(folders) do
                local emoji = get_emoji(folder, true)
                html_body = html_body .. '<tr><td>' .. emoji .. ' <a href="/files?dir=' .. url.escape(dir .. "/" .. folder) .. '">' .. folder .. '</a></td></tr>'
            end
            for _, file in ipairs(files) do
                local emoji = get_emoji(file, false)
                html_body = html_body .. '<tr><td>' .. emoji .. ' <a href="/download?file=' .. url.escape(dir .. "/" .. file) .. '" download="' .. file .. '">' .. file .. '</a></td></tr>'
            end
            html_body = html_body .. '</tbody></table>' .. html.footer()
            send_response(client_socket, "200 OK", "text/html", html_body)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- Download file
    elseif method == "GET" and path:match("^/download%?file=") then
        if auth.is_authorized(headers, G_reader_settings) then
            local file_name = path:match("^/download%?file=(.+)")
            if file_name then
                file_name = url.unescape(file_name)
                local attr = lfs.attributes(file_name)
                if not attr then
                    local html_body = html.header("Error") .. "<div class='msg'>File not found: <b>" .. file_name .. "</b><br>Check the path and filename. The file must exist and be readable by the server.</div>" .. html.footer()
                    send_response(client_socket, "404 Not Found", "text/html", html_body)
                    return
                end
                if attr.mode ~= "file" then
                    local html_body = html.header("Error") .. "<div class='msg'>Requested path is not a regular file: <b>" .. file_name .. "</b><br>Only regular files can be downloaded.</div>" .. html.footer()
                    send_response(client_socket, "404 Not Found", "text/html", html_body)
                    return
                end
                local file = io.open(file_name, "rb")
                if file then
                    local file_data = file:read("*all")
                    file:close()
                    if not file_data or type(file_data) ~= "string" then
                        local html_body = html.header("Error") .. "<div class='msg'>File is empty or could not be read: <b>" .. file_name .. "</b><br>Check file permissions and contents.</div>" .. html.footer()
                        send_response(client_socket, "404 Not Found", "text/html", html_body)
                        return
                    end
                    local file_to_download = file_name:match("([^/]+)$")
                    local last_modified = ""
                    if attr.modification then
                        last_modified = tostring(os.date("%a, %d %b %Y %H:%M:%S GMT", attr.modification))
                    end
                    local response = "HTTP/1.1 200 OK\r\n"
                    response = response .. "Content-Disposition: attachment; filename=" .. file_to_download .. "\r\n"
                    if last_modified ~= "" then
                        response = response .. "Last-Modified: " .. last_modified .. "\r\n"
                    end
                    response = response .. "Date: " .. os.date("%a, %d %b %Y %H:%M:%S GMT") .. "\r\n"
                    response = response .. "Server: MyUpload Server\r\n"
                    response = response .. "Content-Length: " .. #file_data .. "\r\n"
                    response = response .. "\r\n" .. file_data
                    client_socket:send(response)
                else
                    local html_body = html.header("Error") .. "<div class='msg'>File exists but could not be opened for reading: <b>" .. file_name .. "</b><br>Check file permissions.</div>" .. html.footer()
                    send_response(client_socket, "404 Not Found", "text/html", html_body)
                end
            else
                local html_body = html.header("Bad request.") .. "<div class='msg'>Invalid file request. No file specified.</div>" .. html.footer()
                send_response(client_socket, "400 Bad Request", "text/html", html_body)
            end
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- Upload form
    elseif method == "GET" and path == "/upload" then
        if auth.is_authorized(headers, G_reader_settings) then
            local html_body = html.header("Upload eBook") .. [[
            <form action="/upload" method="POST" enctype="multipart/form-data">
                <input type="file" name="file" required><br>
                <input type="submit" value="Upload">
            </form>
            ]] .. html.footer()
            send_response(client_socket, "200 OK", "text/html", html_body)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- Handle file upload (simple, single file, no boundary parsing)
    elseif method == "POST" and path == "/upload" then
        if auth.is_authorized(headers, G_reader_settings) then
            local content_type = headers["content-type"] or ""
            local boundary = content_type:match("boundary=([%w%-_]+)")
            if not boundary then
                local html_body = html.header("Bad request.") .. "<p>Missing boundary in Content-Type.</p>" .. html.footer()
                send_response(client_socket, "400 Bad Request", "text/html", html_body)
                return
            end

            local function read_line(sock)
                local line = ""
                while true do
                    local char, err = sock:receive(1)
                    if not char or char == "" then
                        if DEBUG.is_on then logger.dbg("[BookDrop] read_line: EOF or error while reading (line so far: '" .. line:gsub("\r", "\\r"):gsub("\n", "\\n") .. "')") end
                        return nil
                    end
                    line = line .. char
                    if char == "\n" then break end
                end
                return line
            end

            -- Read headers until file part
            local boundary_str = "--" .. boundary
            local end_boundary_str = boundary_str .. "--"
            local found_file = false
            local filename = nil
            local allowed_exts = {"epub", "pdf", "azw3", "mobi", "docx", "txt", "cbz"}
            local ext_ok = false
            local file_path = nil
            local file = nil
            while true do
                local line = read_line(client_socket)
                if not line then
                    if DEBUG.is_on then logger.dbg("[BookDrop] End of headers or error before file part found.") end
                    break
                end
                if line:find("Content-Disposition: form-data;", 1, true) and line:find("filename=") then
                    if DEBUG.is_on then logger.dbg("[BookDrop] Found Content-Disposition header with filename.") end
                    filename = line:match('filename="([^"]+)"')
                    if filename then
                        for _, ext in ipairs(allowed_exts) do
                            if filename:lower():match("%." .. ext .. "$") then ext_ok = true break end
                        end
                        file_path = upload_dir .. "/" .. filename
                        file = io.open(file_path, "wb")
                        if not file then
                            if DEBUG.is_on then logger.dbg("[BookDrop] Error opening file for writing: " .. tostring(file_path)) end
                            break
                        end
                        found_file = true
                        if DEBUG.is_on then logger.dbg("[BookDrop] Ready to write file: " .. file_path) end
                    end
                end
                if found_file and line == "\r\n" then
                    if DEBUG.is_on then logger.dbg("[BookDrop] End of headers, file content starts next.") end
                    break -- End of headers, file content starts next
                end
            end
            if not found_file or not ext_ok or not file then
                if file then file:close() end
                local html_body = html.header("Upload of file") .. "<p>Invalid upload data or extension not allowed.</p>" .. html.footer()
                send_response(client_socket, "400 Bad Request", "text/html", html_body)
                return
            end
            -- Stream file content line by line until the terminating boundary is seen
            local total_bytes = 0
            if DEBUG.is_on then logger.dbg("[BookDrop] Starting file upload stream for " .. (filename or "(unknown)")) end
            local prev_line = nil
            while true do
                local line = read_line(client_socket)
                if not line then
                    if DEBUG.is_on then logger.dbg("[BookDrop] Upload stream ended (no more data or error)") end
                    -- Write the last line if it exists (should not happen for well-formed uploads)
                    if prev_line then
                        file:write(prev_line)
                        total_bytes = total_bytes + #prev_line
                    end
                    break
                end
                -- Remove trailing CRLF for boundary comparison
                local line_stripped = line:gsub("[\r\n]+$", "")
                if line_stripped == boundary_str or line_stripped == end_boundary_str then
                    if prev_line then
                        -- Write previous line without its trailing CRLF
                        local trimmed = prev_line:gsub("[\r\n]+$", "")
                        file:write(trimmed)
                        total_bytes = total_bytes + #trimmed
                    end
                    if DEBUG.is_on then logger.dbg("[BookDrop] Detected terminating boundary, finishing upload.") end
                    break
                end
                if prev_line then
                    file:write(prev_line)
                    total_bytes = total_bytes + #prev_line
                end
                prev_line = line
            end
            file:close()
            if DEBUG.is_on then logger.dbg(string.format("[BookDrop] Upload complete: %s, total bytes written: %d", tostring(filename), total_bytes)) end
            local html_body = html.header("Upload of file") .. "<p>File uploaded successfully: " .. (filename or "(unknown)") .. "</p>" .. html.footer()
            send_response(client_socket, "200 OK", "text/html", html_body)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- List clipboard folder
    elseif method == "GET" and path == "/clipping_dir" then
        if auth.is_authorized(headers, G_reader_settings) then
            if clipping_dir and clipping_dir ~= 'None' then
                local files = file_utils.list_files(clipping_dir)
                table.sort(files)
                local html_body = html.header("Files in folder") ..
                    '<table><thead><tr><th>' .. clipping_dir .. '</th></tr></thead><tbody>'
                for _, file in ipairs(files) do
                    html_body = html_body .. '<tr><td><a href="/download?file=' .. url.escape(clipping_dir .. '/' .. file) .. '" download="' .. file .. '">' .. file .. '</a></td></tr>'
                end
                html_body = html_body .. '</tbody></table>' .. html.footer()
                send_response(client_socket, "200 OK", "text/html", html_body)
            else
                                local html_body = html.header("Files in folder") .. html.clipping_dir_not_set_alert() .. html.footer()
                send_response(client_socket, "200 OK", "text/html", html_body)
            end
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- /folders endpoint removed

    -- List eBooks in folders (paging)
    elseif method == "GET" and path == "/folders_paging" then
        if auth.is_authorized(headers, G_reader_settings) then
            -- Parse query parameters from path if not already available
            local dir = upload_dir
            local qstr = path:match("%?(.+)")
            if qstr then
                for k, v in string.gmatch(qstr, "([^&=?]+)=([^&=?]+)") do
                    if k == "dir" then
                        dir = url.unescape(v)
                        break
                    end
                end
            end
            -- Check if dir is a real directory using file_utils
            if not file_utils.is_dir(dir) then
                local html_body = html.header("Error") ..
                    '<div style="color:red;font-weight:bold;">The path <code>' .. html.html_escape(dir) .. '</code> is not a directory or does not exist.</div>' ..
                    html.footer()
                send_response(client_socket, "404 Not Found", "text/html", html_body)
                return
            end
            -- List folders and files separately
            local folders = file_utils.list_folders(dir)
            local files = file_utils.list_files(dir)
            table.sort(folders)
            table.sort(files)
            local html_body = html.header("Folders and Files (Paged)") ..
                '<table id="dataTable"><thead><tr><th>Name</th><th>Type</th></tr></thead><tbody>'
            for _, folder in ipairs(folders) do
                local folder_name = folder:match("([^/]+)$")
                html_body = html_body .. '<tr><td><a href="/folders_paging?dir=' .. url.escape(folder) .. '">' .. folder_name .. '</a></td><td>Folder</td></tr>'
            end
            for _, file in ipairs(files) do
                local file_name = file:match("([^/]+)$")
                html_body = html_body .. '<tr><td><a href="/download?file=' .. url.escape(file) .. '" download="' .. file_name .. '">' .. file_name .. '</a></td><td>File</td></tr>'
            end
            html_body = html_body .. '</tbody></table>' .. [[
            <div class="pagination">
                <button id="prevBtn" onclick="changePage(-1)">Previous</button>
                <span id="pageInfo">Page 1</span><span id="pageInfoTotal"></span>
                <button id="nextBtn" onclick="changePage(1)">Next</button>
                Jump to Page:
                <input type="number" id="pageInput" min="1" placeholder="Page" onchange="jumpToPage()">
                <button id="jumpBtn" onclick="jumpToPage()">Go</button>
            </div>
            <script>
                const rowsPerPage = 10;
                let currentPage = 1;
                const tableBody = document.querySelector("#dataTable tbody");
                const rows = Array.from(tableBody.rows);
                function renderTable() {
                    const startIndex = (currentPage - 1) * rowsPerPage;
                    const endIndex = Math.min(startIndex + rowsPerPage, rows.length);
                    tableBody.innerHTML = "";
                    for (let i = startIndex; i < endIndex; i++) {
                        tableBody.appendChild(rows[i]);
                    }
                    document.getElementById("pageInfo").textContent = `Page ${currentPage}`;
                    updatePaginationButtons();
                }
                function changePage(direction) {
                    const newPage = currentPage + direction;
                    if (newPage > 0 && newPage <= Math.ceil(rows.length / rowsPerPage)) {
                        currentPage = newPage;
                        renderTable();
                    }
                }
                function updatePaginationButtons() {
                    const totalPages = Math.ceil(rows.length / rowsPerPage);
                    document.getElementById("prevBtn").disabled = currentPage === 1;
                    document.getElementById("nextBtn").disabled = currentPage === totalPages;
                    document.getElementById("pageInfoTotal").textContent = ` of ${totalPages}`;
                }
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
                renderTable();
            </script>
            ]] .. html.footer()
            send_response(client_socket, "200 OK", "text/html", html_body)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- Flat view of all eBooks (no paging)
    elseif method == "GET" and path == "/flat_view_files" then
        if auth.is_authorized(headers, G_reader_settings) then
            local cmd = 'find "'.. upload_dir .. '/" -maxdepth 10 -type f  -name "*.epub" -o -name "*.pdf" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.docx" -o -name "*.cbz" -o -name "*.txt" ! -name "*.opf" ! -name "*.jpg" ! -name "*.gz" ! -name "*.zip" ! -name "*.tar" '
            local files = io.popen(cmd)
            local splitted_files = {}
            if files then
                local file_list = files:read("*a")
                files:close()
                for match in file_list:gmatch("[^\n]+") do table.insert(splitted_files, match) end
            end
            table.sort(splitted_files)
            local html_body = html.header("All eBooks in Home folder") .. '<table><thead><tr><th>' .. upload_dir .. '</th></tr></thead><tbody>'
            for _, file in ipairs(splitted_files) do
                local filename = file:match("([^/]+)$")
                if filename then
                    html_body = html_body .. '<tr><td><a href="/download?file=' .. url.escape(file) .. '" download="' .. filename .. '">' .. filename .. '</a></td></tr>'
                end
            end
            html_body = html_body .. '</tbody></table>' .. html.footer()
            send_response(client_socket, "200 OK", "text/html", html_body)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- Flat view of all eBooks (paging)
    elseif method == "GET" and path == "/flat_view_files_paging" then
        if auth.is_authorized(headers, G_reader_settings) then
            local cmd = 'find "'.. upload_dir .. '/" -maxdepth 10 -type f  -name "*.epub" -o -name "*.pdf" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.docx" -o -name "*.cbz" -o -name "*.txt" ! -name "*.opf" ! -name "*.jpg" ! -name "*.gz" ! -name "*.zip" ! -name "*.tar" '
            local files = io.popen(cmd)
            local splitted_files = {}
            if files then
                local file_list = files:read("*a")
                files:close()
                for match in file_list:gmatch("[^\n]+") do table.insert(splitted_files, match) end
            end
            table.sort(splitted_files)
            local html_body = html.header("All eBooks in Home folder (Paged)") .. '<table id="dataTable"><thead><tr><th>' .. upload_dir .. '</th></tr></thead><tbody>'
            for _, file in ipairs(splitted_files) do
                local filename = file:match("([^/]+)$")
                if filename then
                    html_body = html_body .. '<tr><td><a href="/download?file=' .. url.escape(file) .. '" download="' .. filename .. '">' .. filename .. '</a></td></tr>'
                end
            end
            html_body = html_body .. '</tbody></table>' .. [[
            <div class="pagination">
                <button id="prevBtn" onclick="changePage(-1)">Previous</button>
                <span id="pageInfo">Page 1</span><span id="pageInfoTotal"></span>
                <button id="nextBtn" onclick="changePage(1)">Next</button>
                Jump to Page:
                <input type="number" id="pageInput" min="1" placeholder="Page" onchange="jumpToPage()">
                <button id="jumpBtn" onclick="jumpToPage()">Go</button>
            </div>
            <script>
                const rowsPerPage = 10;
                let currentPage = 1;
                const tableBody = document.querySelector("#dataTable tbody");
                const rows = Array.from(tableBody.rows);
                function renderTable() {
                    const startIndex = (currentPage - 1) * rowsPerPage;
                    const endIndex = Math.min(startIndex + rowsPerPage, rows.length);
                    tableBody.innerHTML = "";
                    for (let i = startIndex; i < endIndex; i++) {
                        tableBody.appendChild(rows[i]);
                    }
                    document.getElementById("pageInfo").textContent = `Page ${currentPage}`;
                    updatePaginationButtons();
                }
                function changePage(direction) {
                    const newPage = currentPage + direction;
                    if (newPage > 0 && newPage <= Math.ceil(rows.length / rowsPerPage)) {
                        currentPage = newPage;
                        renderTable();
                    }
                }
                function updatePaginationButtons() {
                    const totalPages = Math.ceil(rows.length / rowsPerPage);
                    document.getElementById("prevBtn").disabled = currentPage === 1;
                    document.getElementById("nextBtn").disabled = currentPage === totalPages;
                    document.getElementById("pageInfoTotal").textContent = ` of ${totalPages}`;
                }
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
                renderTable();
            </script>
            ]] .. html.footer()
            send_response(client_socket, "200 OK", "text/html", html_body)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end

    -- List files in a specific folder (indir)
    elseif method == "GET" and path:match("^/indir%?dir=") then
        if auth.is_authorized(headers, G_reader_settings) then
            local query_params = url_path_parsing(path)
            local dir_to_list = url.unescape(query_params.dir) or "."
            local files = file_utils.list_files(dir_to_list)
            table.sort(files)
            local html_body = html.header("Files in folder") ..
                '<table><thead><tr><th>' .. dir_to_list .. '</th></tr></thead><tbody>'
            for _, file in ipairs(files) do
                html_body = html_body .. '<tr><td><a href="/download?file=' .. url.escape(dir_to_list .. '/' .. file) .. '" download="' .. file .. '">' .. file .. '</a></td></tr>'
            end
            html_body = html_body .. '</tbody></table>' .. html.footer()
            send_response(client_socket, "200 OK", "text/html", html_body)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end
    elseif method == "GET" and path:match("/favicon.ico") then
        local svg_bytes = require("bookdrop/favicon_svg")
        if svg_bytes then
            send_response(client_socket, "200 OK", "image/svg+xml", svg_bytes)
        else
            send_response(client_socket, "404 Not Found", "text/plain", "Favicon not found")
        end
    else
        if auth.is_authorized(headers, G_reader_settings) then
            local html_body = html.header("Not Found") ..
                [[<p>404 Not Found</p>]] .. html.footer()
            send_response(client_socket, "404 Not Found", "text/html", html_body)
        else
            send_response_location(client_socket, "302 Found", "/login")
        end
    end
end

function M.start_server()
    local G_reader_settings = require("luasettings"):open(require("datastorage").getDataDir().."/settings.reader.lua")
    local port = 8080
    local seconds_runtime = 60
    local Upload_parms = G_reader_settings:readSetting("Upload_parms")
    if Upload_parms then
        if Upload_parms["port"] then
            port = tonumber(Upload_parms["port"]) or 8080
        end
        if Upload_parms["seconds_runtime"] then
            seconds_runtime = tonumber(Upload_parms["seconds_runtime"]) or 60
        end
    end
    M.browser_forced_shutdown = false
    local server_socket = assert(socket.bind('*', port))
    server_socket:settimeout(0)
    if DEBUG.is_on then logger.dbg("Upload server started on port " .. tostring(port)) end
    local function wait(s)
        for _=1, s do
            local lastvar = os.time()
            while lastvar == os.time() do
                local client_socket = server_socket:accept()
                if client_socket then
                    client_socket:settimeout(2)
                    handle_request(client_socket, G_reader_settings)
                    client_socket:close()
                end
                if M.browser_forced_shutdown then break end
            end
            if M.browser_forced_shutdown then break end
        end
    end
    wait(seconds_runtime)
    server_socket:close()
    if DEBUG.is_on then logger.dbg('Upload server stopped') end
end

return M
