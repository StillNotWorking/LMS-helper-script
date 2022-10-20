#!/bin/bash
# 0.0.4 - https://github.com/StillNotWorking/LMS-helper-script
# Scriptet for RPi-OS Lite 64 bit with logged in user 'pi'. If installed 
# with user other than 'pi' edit following two files to reflect this
#   /etc/systemd/system/camilladsp.service
#   /etc/systemd/system/camillagui.service
# aditional to the above two config files these can be altered if needed:
#   /etc/default/squeezelite
#   /camilladsp/gui/config/camillagui.yml
sudo apt update
sudo apt full-upgrade -y
#******  Squeezelite and backend dependencies ******
sudo apt install squeezelite git python3-pip python3-aiohttp python3-jsonschema python3-numpy python3-matplotlib -y
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/squeezelite -P ~/
sudo rm /etc/default/squeezelite
sudo mv ~/squeezelite /etc/default/squeezelite
#******  CamillaDSP install ******
mkdir ~/camilladsp && mkdir ~/camilladsp/configs && mkdir ~/camilladsp/coeffs
# CamillaDSP 1.0.2
wget https://github.com/HEnquist/camilladsp/releases/download/v1.0.2/camilladsp-linux-aarch64.tar.gz -P ~/camilladsp/
tar -xvf ~/camilladsp/camilladsp-linux-aarch64.tar.gz -C ~/camilladsp/
rm ~/camilladsp/camilladsp-linux-aarch64.tar.gz
sudo mv ~/camilladsp/camilladsp /usr/bin/camilladsp
# filter with cdsp config
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/default_config.yml -P ~/camilladsp/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseFO6.4.yml -P ~/camilladsp/configs/
ln -s ~/camilladsp/configs/HouseFO6.4.yml ~/camilladsp/active_config.yml
# more filter configs for demo
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseFO3.2.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseFO4.8.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseFO8.0.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseFO6.4-88.2.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseFO9.6.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseQ3.2.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseQ4.8.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseQ6.4.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseQ8.0.yml -P ~/camilladsp/configs/
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/HouseQ9.6.yml -P ~/camilladsp/configs/
# convelution filter test file
wget https://raw.githubusercontent.com/HEnquist/camilladsp/master/filter.txt -P ~/camilladsp/coeffs/
# aloop.conf
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/aloop.conf
sudo mv aloop.conf /etc/modules-load.d/aloop.conf
sudo modprobe snd-aloop
# asound.conf
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/asound.conf
sudo mv asound.conf /etc/asound.conf
# initialize service files
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camilladsp.service -P ~/camilladsp/
sudo mv ~/camilladsp/camilladsp.service /etc/systemd/system/camilladsp.service
sudo systemctl daemon-reload
sudo systemctl start camilladsp
sudo systemctl enable camilladsp
sudo systemctl restart squeezelite
echo "We should now have a working CamillaDSP installation without web gui"
echo "******  Web interface & Backend  ******"
mkdir ~/camilladsp/gui
# pycamilladsp v1.0.0
pip3 install git+https://github.com/HEnquist/pycamilladsp.git@v1.0.0
# pycamilladsp-plot v1.0.2
pip3 install git+https://github.com/HEnquist/pycamilladsp-plot.git@v1.0.2
# GUI frontend v.1.0.0
wget https://github.com/HEnquist/camillagui-backend/releases/download/v1.0.0/camillagui.zip -P ~/camilladsp/gui
unzip ~/camilladsp/gui/camillagui.zip -d ~/camilladsp/gui/
rm camilladsp/gui/camillagui.zip
mv ~/camilladsp/gui/config/camillagui.yml ~/camilladsp/gui/config/camillagui_org.yml
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camillagui.yml -P ~/camilladsp/gui/config/
# configure camillagui.service 
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camillagui.service -P ~/camilladsp/gui/
sudo mv ~/camilladsp/gui/camillagui.service /etc/systemd/system/camillagui.service
sudo systemctl daemon-reload
sudo systemctl start camillagui
sudo systemctl enable camillagui
echo "Finished - Please reboot and enjoy music from the headphones out on your RPi"