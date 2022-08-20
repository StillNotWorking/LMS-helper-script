# LMS helper scripts
Tools to help maintain headless Logitech Media Server devices for novice Linux users 

#### mountdrive.sh
let user easily add USB storage devices to RPi-OS by listing detected devices and automatically configure <i>fstab</i> for item selected by user for instant access. Drive will then mount automatic at next boot.
#### mountdrive-0.0.2_all.deb
same as above ready to install on RPi-OS (Debian)
```
~$ wget 'https://github.com/StillNotWorking/LMS-helper-script/blob/main/mountdrive-0.0.2_all.deb?raw=true'
~$ sudo apt install ./mountdrive-0.0.2_all.deb
```
When <i>deb</i> files are downloaded manually and user later want to install `apt` will need the full path to the <i>deb</i> install file. Else `apt` will look in its packaging list and give an error.
<br />Here `./` means <i>this directory</i>.
#### lms_bash_aliases.txt
are several aliases (command shortcut) that simplify the control of the LMS system with short single word commands rather than typing 'sudo systemctl [command] logitechmediaserver' + a few shortcuts to directories used by lms.<br />
How to implement aliases: https://github.com/StillNotWorking/LMS-helper-script/blob/main/lms_bash_aliasesREADME.md

#### cover.html
are an exsample how to make custom visualization for any LMS player using html and java. Think lcd screen in a pickture frame and so on.

---------------------------------------------------------------

# How to run a bash script 
simply type: 
```
~$ bash [scriptname]
or 
~$ sudo bash [scriptname] if administrator privileges are needed
```
If one like to have a script as part of the system as a command we make it executable. And for safety have root be the owner of the file.<sup>1</sup>


**Change the file owner and group**
```
~$ sudo chown root:root [filename]
```
**Select one of these two methods to make the script executable:**

`chmod u+x`  your new command must run with `sudo` as file owner 'u=user' are set to root. This can be confusing if one forget `sudo` as the error are as if the file is missing.
```
~$ sudo chmod u+x [filename]
``` 

`chmod a+x`  everyone can run the command
```
~$ sudo chmod a+x [filename]
```
#### Run the script as a command 
without the need to type the full path now copy or move the executable script to the `/usr/bin` directory. Its common to also remove the file exstention `.sh`.
```
~$ sudo mv [filename.sh] /usr/bin/[filename]
```
<i>Linux directory structure are explained here: https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard</i>


We often see guidance to runs script with <b>./</b>[scriptname].
`./` meens <i>this directory</i> and are used to different the local script rather than similar named system command. You might see the logic behind this if you followed the guide how to make your script a system command by moving it to the /bin directory.
There is also another logic in work here as there are no need for the bash command as the system will read the first comment in the script '#!/bin/bash' to determine what script engine to use with the script. Hence the file extention are not needed.



<sup>1</sup> if root is owner you need to use 'sudo' to edit the script.<br />