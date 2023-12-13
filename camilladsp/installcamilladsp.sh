#!/bin/bash
# 2.0.0 - https://github.com/StillNotWorking/LMS-helper-script
# Scriptet for RPi-OS Lite 64-bit with logged in user 'pi'. If installed 
# with user other than 'pi' edit the following two files to reflect this
#   /etc/systemd/system/camilladsp.service
#   /etc/systemd/system/camillagui.service
# Aditional config files used in this install that normally don't need to be changed:
#   /etc/default/squeezelite
#   /camilladsp/gui/config/camillagui.yml
#   /etc/modules-load.d/aloop.conf
#   /etc/asound.conf
#
# try to stop daemons if there already exist an old install
if sudo systemctl is-active --quiet squeezelite ; then
    sudo systemctl stop squeezelite;
fi
if sudo systemctl is-active --quiet camillagui ; then
    sudo systemctl stop camillagui;
fi
if sudo systemctl is-active --quiet camilladsp ; then
    sudo systemctl stop camilladsp;
fi

sudo apt update
sudo apt full-upgrade -y

echo "****** Squeezelite and backend dependencies ******"
sudo apt install squeezelite git python3-pip python3-aiohttp python3-jsonschema python3-numpy python3-matplotlib -y

# Squeezelite configuration
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/squeezelite -P ~/
sudo mv /etc/default/squeezelite /etc/default/squeezelite_$(date +%y%m%d%H%m%s)
sudo mv ~/squeezelite /etc/default/squeezelite

echo "****** CamillaDSP install ******"
# keep existing install with config and filters for reference
if test -d ~/camilladsp; then
    mv ~/camilladsp ~/camilladsp_$(date +%y%m%d%H%m%s);
fi
mkdir ~/camilladsp && mkdir ~/camilladsp/configs && mkdir ~/camilladsp/coeffs

# CamillaDSP 2.0.0
wget https://github.com/HEnquist/camilladsp/releases/download/v2.0.0/camilladsp-linux-aarch64.tar.gz -P ~/camilladsp/
tar -xvf ~/camilladsp/camilladsp-linux-aarch64.tar.gz -C ~/camilladsp/
rm ~/camilladsp/camilladsp-linux-aarch64.tar.gz
sudo mv -b ~/camilladsp/camilladsp /usr/bin/camilladsp

# default_config.yml - a functioning filter for the 1st run of CamillaDSP
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/statefile.yml -P ~/camilladsp/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/SqueezeliteEQ.yml -P ~/camilladsp/configs/

# CDSP from v2 no longer make use of linked files. Now replaced with statefile
#ln -s ~/camilladsp/configs/HouseFO6.4.yml ~/camilladsp/active_config.yml

# more filter configs for demo
#wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseFO3.2.yml -P ~/camilladsp/configs/
#wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseFO4.8.yml -P ~/camilladsp/configs/

# convelution filter test file
wget https://raw.githubusercontent.com/HEnquist/camilladsp/master/filter.txt -P ~/camilladsp/coeffs/

# aloop.conf
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/aloop.conf
sudo mv -b aloop.conf /etc/modules-load.d/aloop.conf
sudo modprobe snd-aloop

# asound.conf
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/asound.conf
sudo mv -b asound.conf /etc/asound.conf

# initialize service files
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camilladsp.service -P ~/camilladsp/
sudo mv -b ~/camilladsp/camilladsp.service /etc/systemd/system/camilladsp.service
sudo systemctl daemon-reload
sudo systemctl start camilladsp
sudo systemctl enable camilladsp
sudo systemctl restart squeezelite

echo "We should now have a working CamillaDSP installation without GUI"
echo ""
echo "****** Ready to install web user interface & backend ******"
mkdir ~/camilladsp/gui

# pycamilladsp v2.0.0
pip3 install git+https://github.com/HEnquist/pycamilladsp.git@v2.0.0

# pycamilladp-plot v2.0.0
pip3 install git+https://github.com/HEnquist/pycamilladsp-plot.git@v2.0.0

# GUI back-end v.2.0.0
wget https://github.com/HEnquist/camillagui-backend/releases/download/v2.0.0/camillagui.zip -P ~/camilladsp/gui
unzip ~/camilladsp/gui/camillagui.zip -d ~/camilladsp/gui/
rm camilladsp/gui/camillagui.zip

# Change the GUI port to 5000 from default 5005
mv ~/camilladsp/gui/config/camillagui.yml ~/camilladsp/gui/config/camillagui_org.yml
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camillagui.yml -P ~/camilladsp/gui/config

# configure camillagui.service, this file is configured with user 'pi'  
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camillagui.service -P ~/camilladsp/gui
if test -f ~/camilladsp/gui/camillagui.service; then
    sudo mv ~/camilladsp/gui/camillagui.service ~/camilladsp/gui/camillagui.service_$(date +%y%m%d%H%m%s);
fi
sudo mv ~/camilladsp/gui/camillagui.service /etc/systemd/system/camillagui.service
sudo systemctl daemon-reload
sudo systemctl start camillagui
sudo systemctl enable camillagui

echo ""
echo "Finished - Please reboot and then enjoy music from the headphones out on your RPi"
echo ""
echo "TIP: Type 'aplay -l' or 'squeezelite -l' and press Enter to list available sound devices"
echo "Then from CamillaDSP web change Playback device to your sound card."