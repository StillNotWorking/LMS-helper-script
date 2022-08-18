# LMS-helper-script
Tools to help maintain headless Logitech Media Server devices for novice users

'mountdrive.sh' let user easily add USB storage devices to RPi-OS by listing detected devices and configure fstab for item selected by user.

---------------------------------------------------------------

To run a bash script simply type: '$ bash [scriptname]' or 'sudo bash' if needed.

If you like to have the script as part of your system as a command you might want to make it executable and for safety have root be the owner.

change the file owner and group
$ sudo chown root:root [filename]

select one of these methods to make the script executable
u+x, command must run with 'sudo' as 'u=user' now are root. This can be confusing if one forget 'sudo' as the error are as if the file is missing.
$ sudo chmod u+x [filename]
a+x, everyone can run the command
$ sudo chmod a+x [filename]

To run the script as a command without the need to type the full path now copy or move the script to the '/bin' directory. You might also want to remove the file exstention '.sh.'
$ sudo mv [filename.sh] /bin/[filename]

(*) if root is owner you need to use 'sudo' to edit the script.

You often see guidance to runs script with <b>./</b>[scriptname].
<b>./</b> meens <i>this directory</i> and are used to different the local script rather than similar named system command. You might see the logic behind this if you followed the guide how to make your script a system command by moving it to the /bin directory.
There is also another logic in work here as there are no need for the bash command as the system will read the first comment in the script '#!/bin/bash' to determine what script engine to use with the script.