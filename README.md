# LMS helper scripts
Tools to help maintain headless Logitech Media Server devices for novice Linux users 

### installcamilladsp.sh
With this script all dependencies, binary and configuration files to make both Squeezelite and CamillaDSP up running on a fresh RPi-OS install. 
**Intended for RPi-OS Lite 64 bit** with user `pi`
### mountdrive.sh
let user easily add USB storage devices to RPi-OS by listing detected devices and automatically configure <i>fstab</i> for item selected by user for instant access. Drive (*partition*) will then mount automatic at next boot.<sup>1</sup>
### mountdrive-0.0.3_all.deb
same as above ready to install on RPi-OS (Debian)
*tip: copy all text including last empty line and paste into terminal before hitting enter*
```bash
wget 'https://github.com/StillNotWorking/LMS-helper-script/raw/main/mountdrive-0.0.3_all.deb'
sudo apt install ./mountdrive-0.0.3_all.deb

```
After install use `mountdrive` to run the command
```
sudo mountdrive
```
When <i>deb</i> files are downloaded manually and user later want to install `apt` will need the full path to the <i>deb</i> install file. Else `apt` will look in its packaging list and give an error.
 - `./` means <i>this directory</i>.
### lms_bash_aliases.txt
are several aliases (command shortcut) meant to simplify the control of the LMS system with short single word commands rather than typing *'sudo systemctl [command] logitechmediaserver'*, plus a few shortcuts to directories used by lms.

[Read how to implement aliases](https://github.com/StillNotWorking/LMS-helper-script/blob/main/lms_bash_aliasesREADME.md)

### cover.html
are an exsample how to make custom visualization for any LMS player using html and java. Think lcd screen in a pickture frame and so on.

---------------------------------------------------------------

# How to run a bash script 
simply type: 
```
~$ bash [scriptname]
or 
~$ sudo bash [scriptname] if administrator privileges are needed
```
If one like to have a script as part of the system as a command we make it executable. And for safety have root be the owner of the file.<sup>2</sup>

**Change the file owner and group**
```
~$ sudo chown root:root [filename]
```
**Select one of these two methods to make the script executable:**

`chmod u+x`  your new command must run with `sudo` as file owner (*u=user*) first are set to root. *This can be confusing if you forget `sudo` as the error message first lead you to belive the file is missing*.
```
~$ sudo chmod u+x [filename]
``` 

`chmod a+x`  Normal, everyone can run the command. *Script will fail or ask for administrator privileges if needed*.
```
~$ sudo chmod a+x [filename]
```

#### Run a script as a command 
without the need to type the full path. Copy or move the executable script to the `/usr/bin` directory. Its common to also remove the file exstention `.sh`.
```
~$ sudo mv [filename.sh] /usr/bin/[filename]
```
<i>Linux directory structure are explained here: https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard</i>


We often see guidance to runs script with `./[scriptname]`.
`./` meens *this directory* and are used to different the local script rather than similar named system command. You might see the logic behind this if you followed the guide how to make your script a system command by moving it to the /bin directory.
There is also another logic in work here as there are no need for the bash command as the system will read the first comment in the script '#!/bin/bash' to determine what script engine to use with the script. Hence the file extention are not needed.


<sup>1</sup> Technically the script are not mounting a drive but rather help user to mount a partition living on the physical drive. There can be multiple partition on the drive where system list the physical drive as sd(a-z) and partitions as sd(a-z)(#).


<sup>2</sup> if root is owner you need to use 'sudo' to edit the script.<br />