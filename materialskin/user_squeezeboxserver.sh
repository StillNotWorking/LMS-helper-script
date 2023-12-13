##!/bin/bash
# Change system privileges for user 'squeezeboxserver'
# rev. 0.0.1 https://github.com/StillNotWorking 
#
#Before we start make a copy of settings in passwd
sudo cp /etc/passwd /etc/passwd_org_squeezeboxserver
#sudo cat /etc/passwd #should read something like this
#squeezeboxserver:x:109:65534:Logitech Media Server,,,:/usr/share/squeezeboxserver:/usr/sbin/nologin
#
#Add shell for user 'squeezeboxserver':
sudo usermod -s /bin/bash squeezeboxserver
#Verify changes in 'passwd': sudo cat /etc/passwd
#squeezeboxserver:x:109:65534:Logitech Media Server,,,:/usr/share/squeezeboxserver:/bin/bash
#
#Add user squeezeboxserver to group 'sudo'
sudo usermod -a -G sudo squeezeboxserver
#
#We need user squeezeboxserver to be able to 'sudo' without password
sudo -i
echo "squeezeboxserver ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_squeezeboxserver-nopasswd
chmod 440 /etc/sudoers.d/010_squeezeboxserver-nopasswd
logout
#
#Change owner from 'root' of home directory for user 'squeezeboxserver'
sudo chown -R squeezeboxserver /usr/share/squeezeboxserver
#
#How to list sudo users in group 'sudo' from /etc/group
#sudo getent group sudo | cut -d: -f4
#
#Check which user LMS is running under one could use 'htop'. 
#Or look for 'User=' in the startup file
#sudo cat /lib/systemd/system/logitechmediaserver.service