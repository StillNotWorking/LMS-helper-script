#!/bin/bash
# version 0.0.1 - https://github.com/StillNotWorking/LMS-helper-script
# Forward Volume control from LMS to CamillaDSP 
# Install as daemon om Debian based system 
  
# stop daemons if there already exist an old install
if sudo systemctl is-active --quiet volumelms2cdsp ; then
    sudo systemctl stop volumelms2cdsp;
fi

echo 'This will install a daemon to control volume on CamillaDSP from LMS web UI'
echo 'Install consist of only two files:'
echo '  /usr/bin/volumelms2cdsp'
echo '  /etc/systemd/system/volumelms2cdsp.service'
echo ''
read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [nN][eE][sS] ]] || exit 1

# get files
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/volumelms2cdsp.py
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/volumelms2cdsp.service

# install dependences
sudo pip install telnetlib3

echo ''
echo 'Prepare the following information:'
echo '  Player MAC address - can be found under the information menu'
echo '  LMS server address'
echo '  LMS Command Line Interface (CLI) port number - default on server is 9090, can be changed from Server -> Plugins -> Command Line Interface (CLI)'
echo '  CamillaDSP back-end port number - often default to 1234 '
echo ''

read -p "Enter Player MAC address: " playermac
read -p "Enter LMS address: " lmsaddr
read -p "Enter LMS port: " lmsport
read -p "Enter CamillaDSP back-end port: " cdspport

sudo mv -b volumelms2cdsp.py /usr/bin/volumelms2cdsp
sudo chmod g+w /usr/bin/volumelms2cdsp
sudo chow root:root /usr/bin/volumelms2cdsp

# build startup string
# ExecStart=/usr/bin/volumelms2cdsp 00:00:00:00:00:00 127.0.0.0 9090 1234
servicefile='volumelms2cdsp.service'
key='ExecStart='
startstring="ExecStart=\/usr\/bin\/volumelms2cdsp "
startstring+="${playermac} "
startstring+="${lmsaddr} "
startstring+="${lmsport} "
startstring+="${cdspport}"

# Now update service file
#  /^$KEY/       - beginning of line should begin with
#  s/.*/string/  - substitute whatever with string
sudo sed -i -e "/^$key/ s/.*/$startstring/" $servicefile

sudo mv -b volumelms2cdsp.service /etc/systemd/system/volumelms2cdsp.service
sudo chown root:root /etc/systemd/system/volumelms2cdsp.service

sudo systemctl daemon-reload
sudo systemctl start volumelms2cdsp
sudo systemctl enable volumelms2cdsp

if sudo systemctl is-active --quiet volumelms2cdsp ; then
    echo 'Successful install! volumelms2cdsp seems to be up running.'
fi