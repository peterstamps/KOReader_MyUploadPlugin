Last updated: 2025-04-20 time 22:30 CET
Download at https://github.com/peterstamps/KOReader_MyUploadPlugin

VALID LICENSE FOR THIS PLUGIN IS AGPL Version 3.0


This plugin that allows you to use a browser on your PC or your smart phone to upload ebooks into the Home folder of your KOReader.
Uploads are possible for with extension types "epub", "pdf", "azw3", "mobi", "docx" and "txt".

That happens wireless via your home wifi or via your hotspot on your phone or via any network as long as the browser device and device with KOReader can 'see', so can connect via HTTP on the port number set in the plugin. The plugin has a function to generate a QRcode for the Login on your smart phone or PC for example.
A own defined username and password can also be set in the plugin. The default is username is "admin" with password "1234" (without the double quotes!).

The plugin starts a webserver on the KOReader device at the defined port (default 8080). 
That webserver runs for the number op seconds you have set (default 60 seconds = 1 min maximum 15min) and stops automatically to save you a battery drain!
The ebooks appear automatically in the folder that you have set as Home folder. 
So that could be any folder that KOReader can access on the ereader device and that provides write access.

BTW: this is not an wireless upload via VPN or a third party... Nobody else is needed or involved. Just you and your LAN. 
If you use the standard available Hotspot function of your phone and you connect your ereader to your own hotspot then you have a LAN to work with.

If your friend connects also to that Hotspot then you can exchange ebooks directly via upload/download.

The browser menu provides various (sorted) folder listings from where you can download ebooks and all other shown files.
You can also download all your clipping files that contain the notes you made in your ebooks from the clipboard folder that you have set in KOreader.

See the screen prints to get an overview.

Note for Kindle users: read comment in file firewall_rule_for_kindle.txt as the Kindle firewall seems to block this plugin. 


Remedy when ip 127.0.0.1 is set!!!!!

IMPORTANT TO AVOID ISSUES WITH CONNECTIONS....

MAKE SURE BEFORE STARTING THE PLUGIN THAT YOU HAVE WIFI ON AND THAT THE DEVICE IS CONNECTED TO YOUR LAN, SO THAT IT HAS AN REAL LAN IP!!

Installation

Locate folder where KOReader is installed, 
e.g. on Kobo :
  /mnt/onboard/.adds/koreader/
The plugins directory will be:
  /mnt/onboard/.adds/koreader/plugins
 
Create  in plugins the sub directory MyUpload.koplugin like:
  /mnt/onboard/.adds/koreader/plugins/MyUpload.koplugin
 
Now unzip MyUpload.koplugin.zip and copy these two files:
 _meta.lua 
main.lua 
into the new sub directory .../plugins/MyUpload.koplugin.

Open folder  /mnt/onboard/.adds/koreader/plugins/MyUpload.koplugin and check that these two files are in that directory!

Done. Now start KOReader

See /search also Reddit KOreader

