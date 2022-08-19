# LMS-helper-script
Tools to help maintain headless Logitech Media Server devices for novice users

#### mountdrive.sh
let user easily add USB storage devices to RPi-OS by listing detected devices and configure fstab for item selected by user.

#### lms_bash_aliases.txt
are several aliases (command shortcut) that simplify the control of the LMS system with short single word commands rather than typing 'sudo systemctl [command] logitechmediaserver' + a few shortcuts to directories used by lms.<br />
How to implement aliases: https://github.com/StillNotWorking/LMS-helper-script/blob/main/lms_bash_aliasesREADME.md

---------------------------------------------------------------

To run a bash script simply type: '$ bash [scriptname]' or 'sudo bash' if needed.<br />
<br />
If you like to have the script as part of your system as a command you might want to make it executable and for safety have root be the owner.*<br />
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
To run the script as a command without the need to type the full path now copy or move the script to the '/bin' directory. You might also want to remove the file exstention '.sh.'<br />
~$ sudo mv [filename.sh] /bin/[filename]<br />
<br />
(*) if root is owner you need to use 'sudo' to edit the script.<br />
<br />
You often see guidance to runs script with <b>./</b>[scriptname].<br />
<b>./</b> meens <i>this directory</i> and are used to different the local script rather than similar named system command. You might see the logic behind this if you followed the guide how to make your script a system command by moving it to the /bin directory.
There is also another logic in work here as there are no need for the bash command as the system will read the first comment in the script '#!/bin/bash' to determine what script engine to use with the script. Hence the file extention are not needed.