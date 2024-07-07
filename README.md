# LMS helper scripts
Tools to help maintain headless **Logitech Media Server** devices for novice Linux users 

### installcamilladsp.sh
With this script all dependencies, binary and configuration files to make both Squeezelite and CamillaDSP up running on a fresh RPi-OS install. 
**Intended for RPi-OS Lite 64 bit** but should work on most Debian style distros
https://github.com/StillNotWorking/LMS-helper-script/tree/main/camilladsp
### atc.py
ATC is a utility program designed for Lyrion Music Server and CamillaDSP, aimed at minimizing the number of audio rendering stages. Its functionality includes switching sample rates, adjusting volume, applying replay gain, and controlling CPU speed.
https://github.com/StillNotWorking/LMS-helper-script/tree/main/atc
### squeezetoggle.sh
Restart Squeezelite with alternative configuration. Here used to toogle Squeezelite output between sound cards or loopback devices, e.g loopback used for input on CamillaDSP or output direcly to a USB DAC. See custom menus on how to run script from Material Skin.
https://github.com/StillNotWorking/LMS-helper-script/tree/main/materialskin#readme
### materialskin
Add custom menus to Material Skin to run bash commands on local and remote computers 
https://github.com/StillNotWorking/LMS-helper-script/tree/main/materialskin
### material skin snappiness
Run LMS cache directory from a RAM disk
https://github.com/StillNotWorking/LMS-helper-script/tree/main/lms2ram#run-lms-cache-directory-from-ram-drive
### scaling_governor.sh
Scale CPU speed based on current time. Run as cron job hourly we can lock high CPU speed and quick response at daytime. And save power and enhance longevity to our RPI at night.
### cpuspeeed.py
Adjust CPU speed based on whenever Squeezelite is playing or paused
https://github.com/StillNotWorking/LMS-helper-script/tree/main/cpuspeed
### mountdrive.sh
Let user easily add USB storage devices to RPi-OS by listing detected devices and automatically configure <i>fstab</i> for item selected by user for instant access. Drive (*partition*) will then mount automatic at next boot.<sup>1</sup>
### mountdrive-0.0.3_all.deb
Same as above ready to install on RPi-OS (Debian)
*tip: copy all text including last empty line and paste into terminal before hitting enter*
```bash
wget 'https://github.com/StillNotWorking/LMS-helper-script/raw/main/mountdrive-0.0.3_all.deb'
sudo apt install ./mountdrive-0.0.3_all.deb

```
After install use `mountdrive` to run the command
```
sudo mountdrive
```
When <i>deb</i> files are downloaded manually and user later want to install the file using `apt` it will need the full path to the <i>deb</i> install file. Else `apt` will look in its packaging list and give an error.
 - `./` means <i>this directory</i>.
### lms_bash_aliases.txt
Several aliases (command shortcut) meant to simplify the control of the LMS system with short single word commands rather than typing *'sudo systemctl [command] lyrionmusicserver'*, plus a few shortcuts to directories used by LMS.
After install type `lmshelp` to get the list of commands. Now updated to support name change to Lyrion Music Server, LMS version 9.

[Read how to implement these aliases](https://github.com/StillNotWorking/LMS-helper-script/blob/main/lms_bash_aliasesREADME.md)

### cover.html
Are an exsample how to make custom visualization for any LMS player using html and java. Think lcd screen in a pickture frame and so on.

Possible better solution today would be to use Material Skins layout and action parameters
`http://192.168.1.3:9000/material/?layout=desktop&action=expandNowPlaying/true`

Material Skin manual https://github.com/CDrummond/lms-material/wiki/03-Actions

### .bashrc
Change color on command prompt to help different multiple RPi terminals. Overwrite existing `~/.bashrc` in user home directory.
Will also enable aliases `la` 'ls -lhA' `ll` 'ls -lh' and `l` 'ls -CF'

Like to temporary test new settings copy & paste line below. Log out and in to remove. Or first save `PS1` to a variable as shown in screen dump below.
```
PS1="\[\033[47m\]\[\033[30m\]\u@\h\[\033[00m\]:\[\033[32m\]\w\[\033[00m\] \$ "
```
<img src="/img/consol.png" style=" width:98% "  >

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

### When SSH can get you into trouble
One important consideration when managing a headless Linux computer via SSH is to understand that any processes or scripts initiated within that session will typically terminate as well when the SSH session is closed.
![htop process three](/img/processthree.jpg)
Although this is generally not an issue, it's prudent to be mindful when the script or application in question involves writing to storage devices. Despite the expectation that the SSH process sends a SIGHUP to open applications, I've encountered instances of filesystem corruption when the SSH session unexpected terminate due to power saving on client side.

There are several methods to address this problem, with one usually not requiring additional installation.
[`nohup`](https://www.gnu.org/software/coreutils/nohup) runs the given command with hangup signals ignored, so that the command can continue running in the background after you log out.

Output will normally go to file `nohup.out`. If we require the ability to read the output we can use [`tail -f nohup.out`](https://www.gnu.org/software/coreutils/tail). The limitation with this solution is the inability to interact directly with the application. Stopping the application would then require logging into the machine from another SSH session and executing `pgrep -f "appname" | xargs kill -TERM`. Or use [`htop`](https://htop.dev/) to find and stop the application. 

Better solution could possible be to use a dedicated SSH client software that better handles interruptions.
> Both [`screen`](https://savannah.gnu.org/projects/screen) and [`tmux`](https://tmux.github.io/) are client-side applications. They allow you to manage multiple terminal sessions within a single SSH connection. When you run screen or tmux on an SSH session, you're essentially creating a virtual terminal session that persists even if the SSH connection is terminated. This enables you to interact with applications running on the server side in a detached state.

---------------------------------------------------------------

<sup>1</sup> Technically the script are not mounting a drive but rather help user to mount a partition living on the physical drive. There can be multiple partition on the drive where system list the physical drive as sd(a-z) and partitions as sd(a-z)(#).


<sup>2</sup> if root is owner you need to use 'sudo' to edit the script.<br />
