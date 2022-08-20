# LMS helper scripts
Tools to help maintain headless Logitech Media Server devices for novice Linux users 

#### mountdrive.sh
Let user easily add USB storage devices to RPi-OS by listing detected devices and automatically configure fstab for item selected by user for instant access. Drive will then mount automatic at next boot.
#### mountdrive-0.0.2_all.deb
same as above ready to install on RPi-OS (Debian)

sudo apt install 'https://github.com/StillNotWorking/LMS-helper-script/blob/338ac7189d450af57bd0a6ff198396ea4acd672b/mountdrive-0.0.2_all.deb'

if deb files are downloaded manually and then user later want to install `apt` will need the full path to the <i>deb</i> install file. Else `apt` will look in its packaging list and give an error.
'sudo apt install ./mountdrive-0.0.2_all' where `./` means <i>this directory</i>.
#### lms_bash_aliases.txt
are several aliases (command shortcut) that simplify the control of the LMS system with short single word commands rather than typing 'sudo systemctl [command] logitechmediaserver' + a few shortcuts to directories used by lms.<br />
How to implement aliases: https://github.com/StillNotWorking/LMS-helper-script/blob/main/lms_bash_aliasesREADME.md

#### cover.html
are an exsample how to make custom visualization for any LMS player using html and java. Think lcd screen in a pickture frame and so on.

---------------------------------------------------------------

To run a bash script simply type: '$ bash [scriptname]' or 'sudo bash' if needed.<br />
<br />
If you like to have the script as part of your system as a command you might want to make it executable and for safety have root be the owner.<sup>1</sup><br />
<br />
<b>change the file owner and group</b><br />
~$ sudo chown root:root [filename]<br />
<br />
<b>select one of these two methods to make the script executable:</b><br />
`chmod u+x`  your new command must run with 'sudo' as file owner 'u=user' are set to root. This can be confusing if one forget 'sudo' as the error are as if the file is missing.<br />
~$ sudo chmod u+x [filename]<br />
<br /> 
`chmod a+x`  everyone can run the command<br />
~$ sudo chmod a+x [filename]<br />
<br />
To run the script as a command without the need to type the full path now copy or move the script to the '/usr/bin' directory. You might also want to remove the file exstention '.sh.'<br />
~$ sudo mv [filename.sh] /usr/bin/[filename]<br />

<i>Linux directory structure are explained here: https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard</i>
<br />
<br />
You often see guidance to runs script with <b>./</b>[scriptname].<br />
<b>./</b> meens <i>this directory</i> and are used to different the local script rather than similar named system command. You might see the logic behind this if you followed the guide how to make your script a system command by moving it to the /bin directory.
There is also another logic in work here as there are no need for the bash command as the system will read the first comment in the script '#!/bin/bash' to determine what script engine to use with the script. Hence the file extention are not needed.

<br /><br />
<sup>1</sup> if root is owner you need to use 'sudo' to edit the script.<br />