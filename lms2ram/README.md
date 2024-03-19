# Run LMS cache directory from RAM drive
On Linux plugins and SQLite database files used by LMS and plugins are installed in the directory `/var/lib/squeezeboxserver/cache`

The idea is to take benefit of the much improved read speed to evaluate if Material Skin becomes more responsive on the client side.
From a well-reputed SD card brand stated 200MB/s read speed our RPi5 usually return a low 15MB/s in direct read mode and 40MB/s in nocache mode. While the RAM disk give us a wopping **3.5GB/s**.
```bash
echo ''; echo '------ µSD card Write -----------------------------------------'
sudo dd if=/dev/zero of=/var/lib/squeezeboxserver/delete_me bs=4K count=2K oflag=direct
echo ''; echo '------ µSD card Read  -----------------------------------------'
sudo dd of=/dev/zero if=/var/lib/squeezeboxserver/delete_me bs=4K count=2K iflag=direct
sudo dd of=/dev/zero if=/var/lib/squeezeboxserver/delete_me bs=4K count=2K
```

### How does i work?
A RAM disk is mounted. Then the `cache` directory is copied over and pointet to with a symbolic link.

[Inotifywait](https://linux.die.net/man/1/inotifywait) is used to track which files are createt or updated on the RAM drive. When the script receive exit signal from the system those files are copied back to the µSD card — if they still exist after LMS daemon first is stopped.

Test show that CPU speed can matter for how responcive the web GUI feels. Therefore script will by default alter CPU scaling governor to `performance`. Can be disabled with the `-c` argument.

### How to install and use
On the LMS server download script to your home directory. Run script with the -v argument to get to know how it works.

```bash
wget https://github.com/StillNotWorking/LMS-helper-script/tree/main/lms2ram/lms2ram.sh

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

While script can run as a service it might be better to have crontab start it in the hours the music server are in active use. Then stop it at nightime. This due to we also control CPU speed and power saving when system not in use might be beneficial. Remember LMS will function as normal, any practical changes here are how snappy the GUI feels.
```bash
# stop the script from another script or crontab
pgrep -f "lms2ram.sh" | xargs kill -TERM

# start the script
bash /full/path/lms2ram.sh

# edit cronjob
sudo nano /etc/crontab
```
---------------------------------------------------------------

<span style="color:red; font-weight:bold;">WARNING</span> - Undersized RAM-disk size can cause system crash

Default RAM disk size is calculated from directory size +20%. This can be way to small if program is run before scanning new local or remote music archive. A collection of 4500 albums could take up approximately 1850MB. Just add the size you need in MB as argument if this could be problem `lms2ram.sh 2048` This creates a 2GB RAM-disk

Memory seem to be allocated dynamicly on RPI-OS. Where large RAM-disk size doesn't seem to block rest of the memory if there aren't any actually files there to use up the space allocated.
