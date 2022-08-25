# lms_bash_aliases.txt

#### 'lms_bash_aliases.txt' are aliases (command shortcut) that simplify the control of the LMS system with short single word commands rather than typing 'sudo systemctl [command] logitechmediaserver', and a few shortcuts to directories used by lms.<br />
---------------------------------------------------------------
Note: intended used with *systemd -> logitechmediaserver.service* config as used by RPi-OS (Debian). System where lms start from */etc/initd/logitechmediaserver* need som adjusting.

 - **`lmsstatus`** - service status
 - **`lmsrestart`** - service restart
 - **`lmsstart`** - service start
 - **`lmsstop`** - service stopt
 - **`lmseditstart`** - edit service config
 - **`lmsprefs`** - open directory
 - **`lmsplugins`** - open directory
 - **`lmslogs`** - open directory
 - **`lmshelp`** - list the real command behind the alias, same as '~$ alias'


There are a number of ways to implement these aliases. The quickest way is to copy text line below and run the string of commands from command prompt:
```
cd && wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/lms_bash_aliases.txt && cat lms_bash_aliases.txt >> .bash_aliases && cat .bash_aliases
```
This will download the text file and append the command shortcuts to the end of your '.bash_aliases' file inside your home directory. If the file doesn't exist it will be created.



Some might feel safer edit the hidden file `.bash_aliases` themself using an text editor. *On a fresh RPi-OS Lite install users individually aliases file are not yet created*.


Or one can copy the text from the '*lms_bash_aliases.txt*' file and append it between these commands on the command promt:
```
~$ echo 'all text inluding line feed here >> .bash_aliases
```
**New aliases are available at next login.**