# Run LMS cache directory from RAM drive
On Linux plugins and SQLite database files used by LMS and plugins are installed in the `/var/lib/squeezeboxserver/cache` directory.

The idea is to take benefit of the much improved read speed from RAM to evaluate if Material Skin becomes more responsive on the client side.
From a well-reputed SD card brand stated 200MB/s read speed our RPi5 usually return a low 15MB/s in direct read mode and 40MB/s in nocache mode. While the RAM disk give us a wopping **3.5GB/s**.

In comparison using SSD on USB3 port. Tested with Samsung T7 Shield 4TB read direct: 20.4 MB/s, nocache: 343 MB/s
```bash
# ------ µSD card Write -----------------------------------------
sudo dd if=/dev/zero of=/var/lib/squeezeboxserver/delete_me bs=4K count=2K oflag=direct
# ------ µSD card Read  -----------------------------------------
sudo dd of=/dev/zero if=/var/lib/squeezeboxserver/delete_me bs=4K count=2K iflag=direct
# repeating the iflag=nocache test mutiple times seem to give more realistic results 
sudo dd of=/dev/zero if=/var/lib/squeezeboxserver/delete_me bs=4K count=2K iflag=nocache
```

### How does i function?
A RAM disk is first mounted. Then the `cache` directory is copied over to RAM and with a symbolic link LMS can now read and write to memory rather than the µSD card.

[Inotifywait](https://linux.die.net/man/1/inotifywait) is used to track which files are createt or updated on the RAM drive. When the script receive exit signal<sup>1</sup> from the system those files are copied back to the µSD card — if they still exist after LMS daemon first is stopped. 

There is an option `-r` not to write back to storage. This will initiate the LMS in the same manner as it was last run while operating in normal mode.

Tests indicate that the responsiveness of the web GUI can be influenced by RPi CPU speed. Therefore, the script will automatically adjust the CPU scaling governor to 'performance' unless disabled using the -c argument.

### How to install and use
On the LMS server download script to your home directory. Run script with the -v argument to get to know how it works.

```bash
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/lms2ram/lms2ram.sh

# better safe than sorry - make a backup
sudo cp -rp /var/lib/squeezeboxserver/cache /var/lib/squeezeboxserver/cache-BACKUP

# run script in verbose mode will list all steps it peforms
# then continuous list new and changed files
# use [Ctrl+C] to exit and save all changes on the direcory 
bash ./lms2ram.sh -v

# list optional arguments
bash ./lms2ram.sh -h

```

Current revision the script will not backup files while running — only at exit. One possible mitigation for this could be to run a cron job to stop and then reload the scrip a few seconds later. Please note this will restart LMS twise and possible stop any music stream.

While script can run as a service it might be better to have crontab start it in the hours the music server are in active use. Then stop it at nightime. This is the preferred option as we also control CPU speed and power saving when system not in use might be beneficial. Remember LMS will function as normal, any practical changes here are how snappy the GUI feels.
```bash
# stop the script from another script or crontab
pgrep -f "lms2ram.sh" | xargs kill -TERM

# start the script
bash /full/path/lms2ram.sh

# edit cronjob
sudo nano /etc/crontab
```
---------------------------------------------------------------

## WARNING 
Undersized RAM-disk size can cause system crash

Default RAM disk size is calculated from directory size +20%. This can be way to small if program is run before scanning a new local or remote music archive. The temporary database files may also increase in size before being written to the main database, resulting in data existing in multiple locations during certain periods. A collection of 4500 albums could take up approximately 1850MB. Simply add the size you need in MB as argument if this should be an issue. `lms2ram.sh 2048` wild create a 2GB RAM-disk

It appears that memory is allocated dynamically on RPI-OS. With a large RAM disk size, the rest of the memory doesn't seem to be blocked if there are no actual files using up the allocated space.

[Please be aware of the potential risks](https://github.com/StillNotWorking/LMS-helper-script/tree/main#when-ssh-can-get-you-into-trouble) associated with running an SSH session for scripts that copy files to storage devices.

![htop process three](/img/dbsize.jpg)

### A suggested course of action if something stops functioning
If your system starts behaving strangely at any time, such as when plugin functionality or other features cease to work as intended. Before seeking assistance from developers involved with the malfunctioning component, **please verify if things align as expected without executing this script**.

### Exploring alternative to RAM disk 
With the RPi5 running at 2.4GHz, the advantage of using RAM disks is mostly evident in image-intensive activities, — like browsing artists. The SQLite database here lacks the benefit of short strings of text metadata it temporary can store in memory. It will make an attempt to create a cashe database but makes heavily use of disk I/O, and struggles with over 7000 artist images. Despite being notably faster, even the RAM disk exhibits sluggish performance in this scenario.

We have not tested this, but configure the cache to use a faster SSD disk for storage might give enough improvement? 

If we run the command `sudo systemctl status logitechmediaserver` we learn which path is actually used for the cashe directory.
Somewhat confusing we find LMS has its cache parameter set two places. `/var/lib/squeezeboxserver/prefs/server.prefs` and 
`/lib/systemd/system/logitechmediaserver.service`. Where we also learn the correct place to make changes to the startup is `/etc/default/logitechmediaserver`. Adding a new line like this `Environment="CACHEDIR=/var/lib/squeezeboxserver/cache"` should do the trick.

For compatibility the cashe directory might need to exist in two places for pluggins that use use hard coded path, — or the path found in the server.prefs.
```bash
$ sudo systemctl status logitechmediaserver
● logitechmediaserver.service - Logitech Media Server
     Loaded: loaded (/lib/systemd/system/logitechmediaserver.service; enabled; preset: enabled)
     Active: active (running) since Sun 2024-03-24 15:09:27 CET; 1min 47s ago
   Main PID: 2581 (squeezeboxserve)
      Tasks: 2 (limit: 9260)
        CPU: 2.081s
     CGroup: /system.slice/logitechmediaserver.service
             ├─2581 /usr/bin/perl /usr/sbin/squeezeboxserver --prefsdir /var/lib/squeezeboxserve>
             └─2592 /usr/bin/perl /usr/sbin/squeezeboxserver-resized

Mar 24 15:09:27 LMS5 systemd[1]: Started logitechmediaserver.service - Logitech Media Server.
```
---------------------------------------------------------------

  v0.0.6 now work with new service name for Lyrion Music Server from LMS v9

  v0.0.5 bug fix  

  v0.0.4 added `-r` parameter where nothing is written back to storage when program exit
  
  v0.0.3 changed which exit signals program listen for
  
<sup>1</sup> v0.0.2 now have a delay on exit before it start writing back to storage disk. This is an attempt to avoid corrupting the file system if the exit signal is sent due to power failure.




  
*Developed and tested on RPi5 8GB, RPi-OS Lite 64-bit*