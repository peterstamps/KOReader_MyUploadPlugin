# BookDrop Plugin for KOReader

A simple, wireless file upload and download server for KOReader e-readers and devices.

---

## Features

- **Upload eBooks wirelessly** from your PC or smartphone browser to your KOReader device (e.g., eReader, Android, PC).
- **Supported formats:** `.epub`, `.pdf`, `.azw3`, `.mobi`, `.docx`, `.txt`, `.cbz`.
- **Download eBooks and clippings** from your device via browser.
- **Runs a local HTTP server** (default port: 8080) for secure, local network access.
- **QR code login** for easy access from mobile devices.
- **User authentication** (default: `admin` / `1234`).
- **Auto-shutdown** to save battery (default: 60 seconds, max: 15 min). Manual stop also available.
- **No third-party servers**: all transfers are local, private, and direct.

---

## Installation

1. **Connect your KOReader device via USB** to your PC.
2. **Locate the KOReader plugins directory** (e.g. on Kobo: `/mnt/onboard/.adds/koreader/plugins`).
3. **Create a folder**: `BookDrop.koplugin` inside the plugins directory.

4. **Copy these files** into `BookDrop.koplugin`:

- `_meta.lua`
- `main.lua`
- `bookdrop/`

1. **Eject and restart KOReader**. Start the plugin, check the IP address, then restart KOReader again to activate settings.

---

## Usage

1. **Ensure WiFi is ON** and your device is connected to your LAN (not just 127.0.0.1).
2. **Start the BookDrop plugin** from KOReader's main menu.
3. **Open a browser** on your PC or phone and enter the address shown (e.g. `http://192.168.x.x:8080`).
4. **Login** (default: `admin` / `1234`).
5. **Upload or download files** as needed.
6. **Stop the server** via browser or wait for auto-shutdown.

---

## Troubleshooting

- **Cannot access server from browser?**
  1. Is WiFi ON?
  2. Is the device connected to the LAN? (Check IP)
  3. Does the plugin show only `127.0.0.1`? Use the Reset function, restart KOReader/device, and check again.
  4. Is the Upload Server running? (Menu should be blocked if active)
  5. Browser says "Unable to connect"? The server may have stopped (auto-shutdown).
  6. Still can't connect? Check for firewalls on your router, device, or browser device. Ensure the port is open.
  7. Plugin crashed? Try Reset and Restart.

---

## Update History

- **1.1.6**: Support for `.cbz` files, improved Android download naming, updated Hotspot LAN scenario.
- **1.1.5**: Manual stop via browser, paged book listing, new screen prints.
- **1.1.4**: Reject `.gz`, `.zip`, `.tar` uploads, improved multi-file upload UI.
- **1.1.3**: Ignore empty browser requests to prevent KOReader crash.
- **1.1.2**: Fixed download URL for subfolder eBooks.
- **1.1.1**: Improved error handling for missing clipboard/home folders and IP overrides.
- **1.1**: Kindle firewall rule, fixed clipping file download, expanded README.
- **1.0.2**: Fixed QR code URL spacing.
- **1.0.1**: First release.

---

## License

This project is licensed under the [GNU AGPL v3.0](LICENSE).
