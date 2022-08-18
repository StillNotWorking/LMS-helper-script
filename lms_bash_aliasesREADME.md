#lms_bash_aliases
'lms_bash_aliases.txt' are aliases (command shortcut) that simplify the control of the LMS system with short single word commands rather than typing 'sudo systemctl [command] logitechmediaserver' + a few shortcuts to directories used by lms.<br />
Note: intended used with systemd -> logitechmediaserver.service config as used by RPi-OS (Debian). System where lms start from /etc/initd/logitechmediaserver need som adjusting.<br />
<br /><b>
lmsstatus - service status<br />
lmsrestart - service restart <br />
lmsstart - service start<br />
lmsstop - service stopt<br />
lmseditstart - edit service config<br />
lmsprefs - open directory <br />
lmsplugins - open directory <br />
lmslogs - open directory<br />
lmshelp - same as typing '$ alias'<br />
</b><br />
There are a number of ways to implement these aliases.<br />
The quickest way is to copy text line below and run the string of commands from command prompt:<br />
<br />
cd && wget lms_bash_aliases.txt && cat lms_bash_aliases.txt >> .bash_aliases && cat .bash_aliases<br />
<br />
This will download the txt file and append the commands to the end of your '.bash_aliases' file inside your home directory. If the files doesn't exist it will be created.<br />
<br />
The safest are probebly to edit the hidden file '.bash_aliases' youself using a text editor. On a fresh RPi-OS Lite install the aliases file are not yet created.<br />
<br />
Or you can copy the text from the file and append it between this command on the command promt:<br />
echo [all text inluding line feed here] >> .bash_aliases<br />
<br />
<b>New aliases are available at next login.</b><br />