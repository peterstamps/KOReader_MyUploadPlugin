local M = {}


local function nav_menu()
    return [[
    <nav class="nav">
      <div class="nav-left">
        <a href="/home">Home</a>
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

M.header = header
M.footer = footer
return M
