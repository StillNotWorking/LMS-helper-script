# lms_bash_aliases

#### 'lms_bash_aliases.txt' are aliases (command shortcut) that simplify the control of the LMS system with short single word commands rather than typing 'sudo systemctl [command] logitechmediaserver', and a few shortcuts to directories used by lms.<br />
---------------------------------------------------------------
Note: intended used with systemd -> logitechmediaserver.service config as used by RPi-OS (Debian). System where lms start from /etc/initd/logitechmediaserver need som adjusting.<br />
<br />
<b>
`lmsstatus` - service status<br />
`lmsrestart` - service restart <br />
`lmsstart` - service start<br />
`lmsstop` - service stopt<br />
`lmseditstart` - edit service config<br />
`lmsprefs` - open directory <br />
`lmsplugins` - open directory <br />
`lmslogs` - open directory<br />
`lmshelp` - same as '~$ alias' list the real command behind the alias<br />

<br />
</b>
There are a number of ways to implement these aliases. The quickest way is to copy text line below and run the string of commands from command prompt:<br />
<br />
~$ cd && wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/lms_bash_aliases.txt && cat lms_bash_aliases.txt >> .bash_aliases && cat .bash_aliases<br />
<br />
This will download the text file and append the command shortcuts to the end of your '.bash_aliases' file inside your home directory. If the file doesn't exist it will be created.<br />
<br />
Some might feel safer edit the hidden file '.bash_aliases' for themself using an text editor. <i>On a fresh RPi-OS Lite install users individually aliases file are not yet created</i>.<br />
<br />
Or you can copy the text from the 'lms_bash_aliases.txt' file and append it between these commands on the command promt:<br />
~$ echo [all text inluding line feed here] >> .bash_aliases<br />
<br />
<b>New aliases are available at next login.</b><br />