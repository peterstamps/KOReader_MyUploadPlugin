local M = {}

function M.shutdown_page()
        return [[
        <html><head><title>BookDrop Server Stopped</title><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        body { font-family: Arial, sans-serif; background: #f0f0f0; margin: 0; padding: 0; }
        .shutdownbox {
            background: #fff;
            border-radius: 14px;
            box-shadow: 0 4px 24px 0 rgba(60,80,120,0.10), 0 1.5px 4px 0 rgba(60,80,120,0.08);
            width: 100%;
            max-width: 400px;
            margin: 12vh auto 0 auto;
            padding: 32px 22px 28px 22px;
            display: flex;
            flex-direction: column;
            align-items: center;
            box-sizing: border-box;
            overflow: hidden;
        }
        .shutdownbox h2 {
            font-size: 1.7em;
            margin-bottom: 18px;
            text-align: center;
            color: #b71c1c;
        }
        .shutdownbox p {
            font-size: 1.15em;
            color: #333;
            text-align: center;
            margin-bottom: 0;
        }
        </style></head><body>
        <div class="shutdownbox">
            <h2>BookDrop Server Stopped</h2>
            <p>The BookDrop server has been shut down.<br>You may now close this page.</p>
        </div>
        </body></html>
        ]]
end

function M.login_page(show_logged_out)
    local notification_modal = show_logged_out and M.logout_notification_modal() or ''
    local html_body = [[
            <div class="loginbox">
            <h2>BookDrop Login</h2>
            <form action="/login" method="POST">
            <label for="username">Username:</label>
            <input type="text" id="username" name="username" autocomplete="username" required>
            <label for="password">Password:</label>
            <input type="password" id="password" name="password" autocomplete="current-password" required>
            <input type="submit" value="Login">
            </form>
            </div>
    ]]
    local page = [[<html><head><title>BookDrop Login</title><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>
html, body { height: 100%; margin: 0; padding: 0; box-sizing: border-box; overflow-x: hidden; }
body { font-family: Arial, sans-serif; background: #f0f0f0; min-height: 100vh; width: 100vw; overflow-x: hidden; }
.loginbox {
    background: #fff;
    border-radius: 14px;
    box-shadow: 0 4px 24px 0 rgba(60,80,120,0.10), 0 1.5px 4px 0 rgba(60,80,120,0.08);
    width: 100%;
    max-width: 340px;
    margin: 8vh auto 0 auto;
    padding: 28px 18px 22px 18px;
    display: flex;
    flex-direction: column;
    align-items: stretch;
    box-sizing: border-box;
    overflow: hidden;
}
.loginbox h2 {
    font-size: 1.6em;
    margin-bottom: 18px;
    text-align: center;
    color: #1a237e;
}
.loginbox label {
    margin-bottom: 6px;
    font-weight: 500;
    color: #333;
}
.loginbox input[type="text"],
.loginbox input[type="password"] {
    padding: 12px;
    margin-bottom: 18px;
    border: 1.5px solid #cfd8dc;
    border-radius: 6px;
    font-size: 1em;
    background: #f7fbff;
    width: 100%;
    box-sizing: border-box;
}
.loginbox input[type="submit"] {
    padding: 12px 28px; /* Increased left/right padding for more space */
    background: #1976d2;
    color: #fff;
    border: none;
    border-radius: 6px;
    font-size: 1.1em;
    font-weight: bold;
    cursor: pointer;
    transition: background 0.2s;
}
.loginbox input[type="submit"]:hover {
    background: #1565c0;
}
@media (max-width: 600px) {
    .loginbox {
        margin: 4vh auto 0 auto;
        padding: 18px 6vw 16px 6vw;
        max-width: 98vw;
        box-sizing: border-box;
        overflow: hidden;
    }
}
</style></head><body>]] .. notification_modal .. html_body .. [[</body></html>]]
        return page
end

function M.logout_notification_modal()
        return [[
                <div id="logoutModal" style="position:fixed;top:0;left:0;width:100vw;height:100vh;display:flex;align-items:center;justify-content:center;z-index:9999;background:rgba(0,0,0,0.12);">
                    <div style="background:#e3f2fd;color:#1976d2;padding:22px 36px;border-radius:10px;box-shadow:0 2px 12px rgba(60,80,120,0.18);font-size:1.15em;font-weight:500;min-width:220px;text-align:center;">
                        You have been logged out.
                    </div>
                </div>
                <script>
                setTimeout(function() {
                    var modal = document.getElementById('logoutModal');
                    if (modal) {
                        modal.style.transition = 'opacity 0.5s';
                        modal.style.opacity = 0;
                        setTimeout(function() { if (modal.parentNode) modal.parentNode.removeChild(modal); }, 500);
                    }
                }, 2200);
                // Remove ?loggedout=1 or &loggedout=1 from the URL so modal only shows once
                (function() {
                    var url = window.location.href;
                    if (url.indexOf('loggedout=1') !== -1) {
                        var newUrl = url.replace(/[?&]loggedout=1/, function(match, offset) {
                            // If ?loggedout=1 is the only query, remove the ?
                            if (match === '?loggedout=1') return '';
                            // If &loggedout=1, just remove that part
                            return '';
                        });
                        // Remove trailing ? or & if left
                        newUrl = newUrl.replace(/[?&]$/, '');
                        window.history.replaceState({}, document.title, newUrl);
                    }
                })();
                </script>
        ]]
end

local function nav_menu()
    return [[
    <nav class="nav">
      <div class="nav-left">
        <a href="/upload">Upload eBooks</a>
        <a href="/clipping_dir">Clipboard</a>
        <a href="/files">Home Folder</a>
        <a href="/flat_view_files">All eBooks</a>
      </div>
      <div class="nav-right">
        <a href="/logout" class="nav-action nav-logout">Logout</a>
        <a href="/stop" class="nav-action nav-stop">Stop</a>
      </div>
    </nav>
    ]]
end


local function header(title)
    return [[
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>]] .. (title or "Upload Server") .. [[</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            margin: 0;
            padding: 0;
            background: #f7f7fa;
            min-height: 100vh;
        }
        .container {
            max-width: 900px;
            margin: 32px auto 24px auto;
            padding: 28px 18px 18px 18px;
            background: #fff;
            border-radius: 16px;
            box-shadow: 0 4px 24px 0 rgba(60,80,120,0.10), 0 1.5px 4px 0 rgba(60,80,120,0.08);
        }
        .page-title-block {
            margin-bottom: 8px;
        }
        .page-title {
            font-size: 2.1em;
            font-weight: 700;
            color: #1a237e;
            margin: 0 0 2px 0;
            letter-spacing: 0.5px;
            line-height: 1.1;
        }
        .folder-path {
            font-size: 1.04em;
            color: #607d8b;
            background: #f3f4f8;
            border-radius: 6px;
            padding: 4px 12px;
            margin-bottom: 8px;
            margin-top: 2px;
            word-break: break-all;
            font-family: 'Fira Mono', 'Consolas', 'Menlo', monospace;
        }
        .nav {
            display: flex;
            flex-wrap: wrap;
            justify-content: space-between;
            align-items: center;
            background: #f3f4f8;
            border-radius: 12px;
            padding: 12px 10px 10px 10px;
            margin-bottom: 24px;
            box-shadow: 0 1px 4px rgba(60,80,120,0.04);
        }
        .nav-left, .nav-right {
            display: flex;
            flex-wrap: wrap;
            gap: 8px 18px;
            align-items: center;
        }
        .nav a {
            color: #444;
            font-weight: 500;
            padding: 6px 12px;
            border-radius: 6px;
            text-decoration: none;
            transition: background 0.18s, color 0.18s;
        }
        .nav a:hover, .nav a:focus {
            background: #e0e7ef;
            color: #1976d2;
        }
        .nav .nav-action {
            font-weight: bold;
            margin-left: 6px;
        }
        .nav .nav-logout {
            background: #e3f2fd;
            color: #1976d2;
            border: 1.5px solid #1976d2;
        }
        .nav .nav-logout:hover {
            background: #bbdefb;
            color: #0d47a1;
            border-color: #0d47a1;
        }
        .nav .nav-stop {
            background: #fbe9e7;
            color: #d84315;
            border: 1.5px solid #d84315;
        }
        .nav .nav-stop:hover {
            background: #ffd6cc;
            color: #b71c1c;
            border-color: #b71c1c;
        }
        h1 {
            margin-top: 0;
            font-size: 2em;
            color: #222;
            letter-spacing: 0.5px;
        }
        input, select, textarea {
            width: 100%;
            padding: 10px;
            margin: 10px 0 18px 0;
            border: 1px solid #cfd8dc;
            border-radius: 6px;
            font-size: 1em;
            background: #f7fbff;
            transition: border 0.2s;
        }
        input:focus, select:focus, textarea:focus {
            border: 1.5px solid #1976d2;
            outline: none;
        }
        input[type=submit], button, .pagination button {
            width: auto;
            min-width: 120px;
            background: linear-gradient(90deg, #f5f7fa 0%, #c3cfe2 100%);
            color: #222;
            border: none;
            border-radius: 6px;
            padding: 10px 22px;
            font-weight: bold;
            font-size: 1em;
            margin: 10px 8px 10px 0;
            box-shadow: 0 2px 8px rgba(67,233,123,0.04);
            cursor: pointer;
            transition: background 0.2s, color 0.2s;
        }
        input[type=submit]:hover, button:hover, .pagination button:hover {
            background: #e0e7ef;
            color: #1976d2;
        }
        .pagination {
            margin: 24px 0 8px 0;
            text-align: center;
        }
        .breadcrumb-nav {
            margin: 0 0 18px 0;
            padding: 0;
        }
        .breadcrumb {
            display: inline-block;
            font-size: 1.08em;
            color: #666;
            background: none;
            padding: 0;
            margin: 0;
        }
        .breadcrumb a {
            color: #1976d2;
            text-decoration: none;
            font-weight: 500;
            padding: 0 2px;
            transition: color 0.18s;
        }
        .breadcrumb a:hover {
            color: #43e97b;
            text-decoration: underline;
        }
        .breadcrumb-sep {
            color: #bbb;
            margin: 0 4px;
            font-size: 1.1em;
        }
        .pagination input[type=number] {
            width: 60px;
            margin: 0 8px;
            padding: 7px 10px;
            border-radius: 6px;
            border: 1px solid #b0bec5;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 18px 0 12px 0;
            background: #f7fbff;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 1px 4px rgba(60,80,120,0.07);
        }
        th, td {
            border: 1px solid #e3eafc;
            padding: 12px 14px;
            text-align: left;
        }
        th {
            background: #f3f4f8;
            color: #444;
            font-weight: 600;
        }
        tr:nth-child(even) {
            background: #f0f7ff;
        }
        tr:hover {
            background: #e3f2fd;
        }
        a {
            color: #1976d2;
            text-decoration: none;
            transition: color 0.2s;
        }
        a:hover {
            color: #43e97b;
            text-decoration: underline;
        }
        .error {
            color: #d32f2f;
            font-size: 15px;
            margin: 12px 0;
        }
        .msg {
            margin: 18px 0;
            padding: 14px 18px;
            background: #e3f2fd;
            border-left: 5px solid #1976d2;
            border-radius: 6px;
            color: #1976d2;
            font-size: 1.08em;
        }
        .show-password { margin-top: 10px; }
        @media (max-width: 700px) {
            .container { padding: 8px 2vw; }
            .nav { flex-direction: column; align-items: stretch; gap: 0; }
            .nav-left, .nav-right { flex-direction: column; align-items: stretch; gap: 0; }
            .nav a { margin: 0 0 6px 0; display: block; }
            h1 { font-size: 1.3em; }
            th, td { padding: 7px 4px; }
            input, select, textarea { font-size: 0.98em; }
        }
    </style>
    </head>
    <body>
    <div class="container">
    ]] .. nav_menu() .. [[
    <h1>]] .. (title or "Upload Server") .. [[</h1>
    ]]
end

local function footer()
    return [[</div></body></html>]]
end

function M.html_escape(str)
    if not str then return "" end
    return tostring(str)
        :gsub('&', '&amp;')
        :gsub('<', '&lt;')
        :gsub('>', '&gt;')
        :gsub('"', '&quot;')
        :gsub("'", '&#39;')
end

M.header = header
M.footer = footer
return M
