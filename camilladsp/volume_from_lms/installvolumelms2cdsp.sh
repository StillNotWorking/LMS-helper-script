#!/bin/bash
# version 0.0.1 - https://github.com/StillNotWorking/LMS-helper-script
# Forward Volume control from LMS to CamillaDSP 
# Install as daemon om Debian based system 
  
# try to stop daemons if there already exist an old install
if sudo systemctl is-active --quiet volumelms2cdsp ; then
    sudo systemctl stop volumelms2cdsp;
fi

echo 'This will install a daemon to control volume on CamillaDSP from LMS user interface.'
echo 'Install consist of only two files:'
echo '  /usr/bin/volumelms2cdsp'
echo '  /etc/systemd/system/volumelms2cdsp.service'
echo ''
read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [nN][eE][sS] ]] || exit 1

# get files
#wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/volumelms2cdsp.py
#wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/volumelms2cdsp.service

echo 'Prepare the following information:'
echo '  Player MAC address - can be found under the information menu'
echo '  LMS server address'
echo '  LMS Command Line Interface (CLI) port number - default on server is 9090, can be changed from Server -> Plugins -> Command Line Interface (CLI)'
echo '  CamillaDSP back-end port number - often default to 1234 '
echo ''

read -p "Enter Player MAC address: " playermac
exit 1
sudo mv -b volumelms2cdsp.py /usr/bin/volumelms2cdsp
sudo chmod g+w /usr/bin/volumelms2cdsp

# Now update service file
#SERVICEFILE='/etc/systemd/system/volumelms2cdsp.service'
SERVICEFILE='volumelms2cdsp.service'
KEY='ExecStart='
EXECSTART='/usr/bin/volumelms2cdsp 00:00:00:00:00:00 127.0.0.1 9090 1234'
#  /^$KEY/       - beginning of line should begin with
#  s/.*/string/  - substitute whatever with string
sudo sed -i -e "/^$KEY/ s/.*/$EXECSTART=/" $SERVICEFILE


sudo mv -b volumelms2cdsp.service /etc/systemd/system/volumelms2cdsp.service
sudo chown root:root /etc/systemd/system/volumelms2cdsp.service

sudo systemctl daemon-reload
sudo systemctl start volumelms2cdsp
sudo systemctl enable volumelms2cdsp
sudo systemctl restart volumelms2cdsp