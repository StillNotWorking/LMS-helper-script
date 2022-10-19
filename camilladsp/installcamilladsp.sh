#!/bin/bash
# 0.0.1 - https://github.com/StillNotWorking/LMS-helper-script
# Scriptet for RPi-OS Lite 64 bit with logged in user 'pi'. If installed 
# with user other than 'pi' edit following files to reflect this
#   /etc/systemd/system/camillagui.service
#   /etc/systemd/system/camillagui.service
# aditional to the above two custom config files are:
#   /etc/default/squeezelite
#   /camilladsp/gui/config/camillagui.yml
sudo apt update
sudo apt full-upgrade -y
#******  Squeezelite  ******
sudo apt install squeezelite -y
#wget config -P ~/
sudo mv ~/squeezelite /etc/default/squeezelite
#******  CamillaDSP install ******
mkdir ~/camilladsp && mkdir ~/camilladsp/configs && mkdir ~/camilladsp/coeffs
# CamillaDSP 1.0.2
wget https://github.com/HEnquist/camilladsp/releases/download/v1.0.2/camilladsp-linux-aarch64.tar.gz -P ~/camilladsp/
tar -xvf ~/camilladsp/camilladsp-linux-aarch64.tar.gz -C ~/camilladsp/
rm ~/camilladsp/camilladsp-linux-aarch64.tar.gz
sudo mv ~/camilladsp/camilladsp /usr/bin/camilladsp
# filter with cdsp config
wget /default_config.yml -P ~/camilladsp/
wget /HouseFO6.4.yml -P ~/camilladsp/configs/
ln -s ~/camilladsp/active_config.yml -> /home/pi/camilladsp/configs/HouseFO6.4.yml
# aditional filters
sudo wget https://raw.githubusercontent.com/HEnquist/camilladsp/master/filter.txt -P ~/camilladsp/coeffs/
# aloop.conf
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/aloop.conf
sudo mv aloop.conf /etc/modules-load.d/aloop.conf
sudo modprobe snd-aloop
# asound.conf
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/asound.conf
sudo mv asound.conf /etc/asound.conf
# initialize service files
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/camilladsp.service
sudo mv camilladsp.service /etc/systemd/system/camilladsp.service
sudo systemctl daemon-reload
sudo systemctl start camilladsp
sudo systemctl enable camilladsp
sudo systemctl restart squeezelite
echo "this should have a working CamillaDSP installation without web gui"
echo "******  Web interface & Backend  ******"
mkdir ~/camilladsp/gui
# dependencies for backend
sudo apt install git -y
sudo apt install python3-pip -y
pip3 install aiohttp --no-warn-script-location
pip3 install jsonschema --no-warn-script-location
pip3 install numpy --no-warn-script-location
pip3 install matplotlib --no-warn-script-location
# pycamilladsp v1.0.0
pip3 install git+https://github.com/HEnquist/pycamilladsp.git@v1.0.0
# pycamilladsp-plot v1.0.2
pip3 install git+https://github.com/HEnquist/pycamilladsp-plot.git@v1.0.2
# GUI frontend v.1.0.0
wget https://github.com/HEnquist/camillagui-backend/releases/download/v1.0.0/camillagui.zip -P ~/camilladsp/gui
unzip ~/camilladsp/gui/camillagui.zip -d ~/camilladsp/gui/
rm camilladsp/gui/camillagui.zip
# configure camillagui.service 
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/camillagui.service -P ~/camilladsp/gui/
sudo mv ~/camilladsp/gui/camillagui.service /etc/systemd/system/camillagui.service
sudo systemctl daemon-reload
sudo systemctl start camillagui
sudo systemctl enable camillagui