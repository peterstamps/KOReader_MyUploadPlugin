Last updated: Version 1.1 at 2025-04-22 time 11:15 CET Download at https://github.com/peterstamps/KOReader_MyUploadPlugin

The valid license for this open source plugin is AGPL Version 3.0

IMPORTANT!
See the installation instructions before use. 
They are below in this document/on this page.


INTRODUCTION

This plugin allows you to use a browser on your PC or your smart phone to upload ebooks into the Home folder of your device with KOReader. The device can be an eReader, a smartphone, PC, etc.). Upload is possible for ebooks with extension types "epub", "pdf", "azw3", "mobi", "docx" and "txt".

Upload happens wirelessly via your home Wifi or via the Hotspot on your phone or via any network as long as the device with the Browser and the device with KOReader can connect to each other over the same LAN. The connection is over HTTP only on the port number set in the plugin. 
The plugin has a function to generate a QRcode for the Login on your smart phone or PC for example. 
An own defined username and password can be set as well. 

The default is Login username is "admin" with password "1234" (without the double quotes!).

Before starting the plugin make sure Wifi is ON and the device with KOreader is connected to your LAN.
That is required in order to obtain an IP address which is used to make a connection from a browser to your device. 

The plugin starts a webserver on the KOReader device at the defined port (default 8080). 
That webserver runs for the number op seconds you have set (default 60 seconds = 1 min maximum 15 min) and stops automatically to save you a battery drain! 
The ebooks appear automatically in the folder that you have set as Home folder. 
So that could be any folder that KOReader can access on the device and that provides write access.

BTW: this is not an wireless upload via VPN or a third party... Nobody else is needed or involved. Just you and your LAN. 
If you use the standard available Hotspot function of your smart phone and you connect your ereader to your own Hotspot then you have a LAN to work with.
And if your friend connects also to that Hotspot then you can exchange ebooks directly via upload/download.

The browser menu provides various (sorted) folder listings from where you can download ebooks and all other shown files. You can also download all your clipping files that contain the notes you made in your ebooks from the clipboard folder that you have set in KOreader.

See the github folder with the screen prints to get an overview.

This plugin was developed on Ubuntu 24 and works on Ubuntu 24, Raspberry Pi 4 with Bookworm and Samsung/Android Smartphones when KOReader is installed.
It should also work on KOBO and from version 1.1 probably also on Kindle. Note: Kindle has a firewall installed that blocked previous versions of this Plugin. By adding a firewall rule I hope that it will work on Kindle as well. However I am not sure as I cannot test that.


WHAT TO DO IF YOU CANNOT ACCESS FROM A BROWSER THE UPLOAD SERVER? 

Check the following points:
1. Is Wifi ON? -> Switch on Wifi
2. Is device connected to the LAN? -> Login to your LAN with the KOReader device as an IP is required. Check IP
3. Is Plugin Settings menu function showing your LAN IP -> Use Plugin menu Reset function and Restart again the device. Check Steps 1 and 2 after a restart!
4. Is the Upload Server running? -> Your Menu should be blocked else (re-)start the Upload Server
5. Is your browser showing "Unable to connect" -> Check if the Upload server is still running (see point 4) as the runtime might be over (automatic stop is activated)!
6. You still connect connect after checking above points? -> Is there a firewall blocking the connection? That firewall can be running on your router, your Browser device and/or your KOReader device. The port you have set may not be blocked by the firewall. Maybe some ereader devices with build-in firewall do not allow you to connect to your LAN. If the latter is the case you might be stuck. See the note about Kindle firewall before.
7. Has the plugin crashed? -> You might Restart after a Reset


INSTALLATION
1. Connect via USB cable your KOReader device with a PC or equal device.

2. Locate the folder where KOReader is installed, e.g. on Kobo: /mnt/onboard/.adds/koreader/ 
The plugins directory will be: /mnt/onboard/.adds/koreader/plugins

3. Create in the plugins directory a sub directory called MyUpload.koplugin 
Like this: /mnt/onboard/.adds/koreader/plugins/MyUpload.koplugin

4. Now unzip MyUpload.koplugin.zip and copy following two files into 
   the new sub directory called /mnt/onboard/.adds/koreader/plugins/MyUpload.koplugin
   These two files are:
   _meta.lua 
   main.lua 

5. Check if these two files are in that Folder. No other files are required and no other sub-directories as well.

6. Installation is done. 

7. Now start KOReader and the Plugin Upload Server for the First time, check the IP address and hereafter you MUST RESTART KOReader AGAIN so that the new settings are activated!

See / search also Reddit KOReader for latest news and updates.

See also the screen prints folder in github at: https://github.com/peterstamps/KOReader_MyUploadPlugin/tree/main/Screenprints

UPDATE NOTES

version: 1.0.1
- first release

version: 1.0.2
- Removed the space in the URL generated with plugin function QRCode. Now corrected.

version: 1.1
- Always an Error page was shown when downloading a clipping file. The wrong directory path was set. Now corrected.
- Added Firewall rule for Kindle device which is a copy of the rules as set in the standard HTTP Inspector plugin of KOReader.
- Expanded the README.md file with Installation process and a Checklist for problem solving
