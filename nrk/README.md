# NRK - Favorite links to Norsk Riks Kringkasting
As radio links to NRK found in other radio plugins often link the AAC 48 kbps stream rather than the 192 kbps MP3 stream we made this `favorites.opml` file including 15 radio "station" provided by NRK.

From the Classic web GUI (http://192.168.x.x:9000/Default) there is a merge function found on the bottom of you favorites list.
Press `Edit` (*pen icon*) on the `Favorites` folder, then scroll down to the `Import` button and paiste in this path:
```
https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/nrk/favorites.opml
```
Now using Material Skin web GUI, — from the Favorites list select your favorite NRK station and select `Pin to home page` from dropdown menu. You can Un-pin at any time from Material Skin home page.

*When this is written Material Skin are missing the import button hence the need to temporary use the Classic web GUI by adding `/Default` to the LMS server address.*

### Known limitations:
Radio station icons are now provided but simply link to static image from NRK site. In conversation with NRK support it seems these streams do not publish relevant icons or cover art.

Only link to the `Vestland` region are provided for NRK P1. You can edit this favorite from the web GUI using path to your region found on this page http://lyd.nrk.no/
You want the link ending with `_mp3_h` for the 192 kbps stream.

### Tip:
If you like to edit the `favorites.opml` manually you find the path to the preferences folder on the LMS information page in the web GUI. On Linux this directory is `/var/lib/squeezeboxserver/prefs`
Typically path to custom icons have to be manually edited.

Path to a generic radio image could be "html/images/radio.png". This path is relative to the directory from where the web GUI are loaded. For Linux this path is `/usr/share/squeezeboxserver/HTML/Default/html/images`
