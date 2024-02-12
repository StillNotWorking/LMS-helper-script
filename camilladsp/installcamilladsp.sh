#!/bin/bash
# 2.0.1a - https://github.com/StillNotWorking/LMS-helper-script
# Scriptet for RPi-OS Lite 64-bit, should work on most Debian style distros
# Configuration files used by this install:
#   /etc/systemd/system/camilladsp.service
#   /etc/systemd/system/camillagui.service
#   /etc/systemd/system/volumelms2cdsp.service (optional)
#   /etc/init.d/squeezelite
#   /etc/default/squeezelite
#   /camilladsp/gui/config/camillagui.yml
#   /etc/modules-load.d/aloop.conf
#   /etc/asound.conf

# Program Versions:
vercmdsp="v2.0.1"     # CamillaDSP
verpycdsp="v2.0.0"    # Python CamillaDSP
verpyplot="v2.0.0"    # Python CamillaPlot
verguiback="v2.0.0"   # GUI back-end

# CamillaDSP will install its configuration directory, GUI and back-end 
# into logged-in user's home directory. Service files will be edited accordingly
user=${SUDO_USER:-${USER}}

# take user input before we start install
echo "Hi $user. This will install CamillaDSP configuration and backend into you home directory"
read -p 'Press [Enter] to continue or [N] to exit ' ready
if [[ "$ready" =~ ^([nN])$ ]]; then exit;fi

# found existing install, opt to keep existing configs if they're v2 files
if test -f /usr/bin/camilladsp; then
    string=$(/usr/bin/camilladsp -V)
    # don't ask if configuration from v1.0.3 - not compatible with v2
    if [[ $string == *"CamillaDSP 2."* ]]; then
        read -p 'Keep existing configurations and coefficients? [Y/n] :' keep
    fi
fi

# stop daemons if there already exist an old install
if sudo systemctl is-active --quiet installvolumelms2cdsp ; then
    sudo systemctl stop installvolumelms2cdsp; fi
if sudo systemctl is-active --quiet squeezelite ; then
    sudo systemctl stop squeezelite; fi
if sudo systemctl is-active --quiet camillagui ; then
    sudo systemctl stop camillagui; fi
if sudo systemctl is-active --quiet camilladsp ; then
    sudo systemctl stop camilladsp; fi

# if user already know system are up to date
read -p 'Do you want to upgrade operating system? Recommended! [N/y]' os
if [[ "$os" =~ ^([yY])$ ]]; then
    sudo apt update
    sudo apt upgrade -y
fi

echo '****** Install Squeezelite and backend dependencies ******'
sudo apt install squeezelite git python3-pip python3-aiohttp python3-jsonschema python3-numpy python3-matplotlib -y

# Squeezelite configuration
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/squeezelite -P ~/
sudo mv -b ~/squeezelite /etc/default/squeezelite
sudo chown root:root /etc/default/squeezelite

echo '****** Install CamillaDSP ******'
# keep existing install with config and filters for reference
if test -d ~/camilladsp; then
    backuptime=$(date +%y%m%d%H%m%s)
    mv ~/camilladsp ~/camilladsp_$backuptime
fi

# create diretory structure inside home directory
mkdir ~/camilladsp && mkdir ~/camilladsp/configs && mkdir ~/camilladsp/coeffs

# CamillaDSP - $vercmdsp
wget "https://github.com/HEnquist/camilladsp/releases/download/$vercmdsp/camilladsp-linux-aarch64.tar.gz" -P ~/camilladsp/
tar -xvf ~/camilladsp/camilladsp-linux-aarch64.tar.gz -C ~/camilladsp/
rm ~/camilladsp/camilladsp-linux-aarch64.tar.gz
sudo mv -b ~/camilladsp/camilladsp /usr/bin/camilladsp
sudo chown root:root /usr/bin/camilladsp
sudo chmod a+x /usr/bin/camilladsp

# functioning filter file for the 1st run of CamillaDSP
#wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/statefile.yml -P ~/camilladsp/
#chmod 755 ~/camilladsp/statefile.yml
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/SqueezeliteEQ.yml -P ~/camilladsp/configs/
cp ~/camilladsp/configs/SqueezeliteEQ.yml ~/camilladsp/default_config.yml

# keep existing configs and coefficients or download demo files
if [[ "$keep" =~ ^([yY])$ ]]; then
    # keep existing
    cp -R "~/camilladsp_$backuptime/configs" ~/camilladsp/configs
    cp -R "~/camilladsp_$backuptime/coeffs" ~/camilladsp/coeffs
else
    # download filter/configs and convelution for demo
    wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/SqueezeliteEQ_07.yml -P ~/camilladsp/configs/
    wget https://raw.githubusercontent.com/HEnquist/camilladsp/master/filter.txt -P ~/camilladsp/coeffs/
fi

# alsa configuration - asound.conf
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/asound.conf
sudo mv -b asound.conf /etc/asound.conf

# alsa loopback - aloop.conf
wget https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/aloop.conf
sudo mv -b aloop.conf /etc/modules-load.d/aloop.conf
sudo modprobe snd-aloop

# download service file
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camilladsp.service -P ~/camilladsp/
sudo mv -b ~/camilladsp/camilladsp.service /etc/systemd/system/camilladsp.service
sudo chown root:root /etc/systemd/system/camilladsp.service

# edit service file with correct path to home directory
servicefile='/etc/systemd/system/camilladsp.service'
key='ExecStart='
sudo sed -i -e "/^$key/ s/pi/$user/g" $servicefile
key='User='
sudo sed -i -e "/^$key/ s/pi/$user/" $servicefile
key='Group='
sudo sed -i -e "/^$key/ s/pi/$user/" $servicefile

# we should now have a working CamillaDSP installation without GUI

echo ''
echo '****** Install CamillaDSP web user interface & backend ******'

mkdir ~/camilladsp/gui

# pycamilladsp - $verpycdsp
pip3 install git+https://github.com/HEnquist/pycamilladsp.git@$verpycdsp

# pycamilladp-plot - $verpyplot
pip3 install git+https://github.com/HEnquist/pycamilladsp-plot.git@$verpyplot

# GUI back-end - $verguiback
wget "https://github.com/HEnquist/camillagui-backend/releases/download/$verguiback/camillagui.zip" -P ~/camilladsp/gui
unzip ~/camilladsp/gui/camillagui.zip -d ~/camilladsp/gui/
rm camilladsp/gui/camillagui.zip

# Change the GUI port to 5000 from default 5005
mv ~/camilladsp/gui/config/camillagui.yml ~/camilladsp/gui/config/camillagui_org.yml
wget 'https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camillagui.yml' -P ~/camilladsp/gui/config

# download and configure camillagui.service
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camillagui.service -P ~/camilladsp/gui
sudo mv -b ~/camilladsp/gui/camillagui.service /etc/systemd/system/camillagui.service
sudo chown root:root /etc/systemd/system/camillagui.service
servicefile='/etc/systemd/system/camillagui.service'
key='User='
sudo sed -i -e "/^$key/ s/pi/$user/" $servicefile

# edit service file with User and correct path to home directory
servicefile="/etc/systemd/system/camillagui.service"
key="ExecStart="
# 'g' at the end = replace every instace of 'pi' with $user
sudo sed -i -e "/^$key/ s/pi/$user/g" $servicefile
key="User="
sudo sed -i -e "/^$key/ s/pi/$user/" $servicefile


# initialize and start daemons
sudo systemctl daemon-reload
sudo systemctl start camillagui
sudo systemctl enable camillagui
sudo systemctl start camilladsp
sudo systemctl enable camilladsp
sudo systemctl restart squeezelite


# Evaluate Squeezelite version - debian package are at v1.9.8 
# sourceforge.net list a test version v2.0.0.1465
if test -f /usr/bin/squeezelite; then
    string=$(/usr/bin/squeezelite -?)
    string="${string%%,*}" # keep everthing before ','
    sqver="${string#* v}"  # remover 'v' and everthing before = version number
    string="${sqver%%.*}"  # only first char left now

    if [[ "$string" == "1" ]]; then   # asumen v1.9.x
        echo "Official Debian Squeezelite package installed are v$sqver"
        read -p "Do you want to update Squeezelite to v2.0.0 from sourceforge.net? [N/y] " update
        if [[ "$update" =~ ^([yY])$ ]]; then
            mkdir ~/tmpdownload
            wget -nv https://sourceforge.net/projects/lmsclients/files/squeezelite/linux/testing/squeezelite-2.0.0.1465-aarch64.tar.gz/download -P ~/tmpdownload
            # check file hash before unpack and install
            if [[ "$(sha1sum download)" == "dba645abf324987dd2068620d629b18915a56046  download" ]] && [[ "$(md5sum download)" == "0170d04ac75f6748ab8b5a51fb66376d  download" ]]; then
                echo "SHA1 and SH5 checksum OK"; echo "Unpack archive:"
                tar -xvf ~/tmpdownload/download -C ~/tmpdownload
                sudo systemctl stop squeezelite
                sudo mv -b ~/tmpdownload/squeezelite /usr/bin/squeezelite
                sudo chown root:root /usr/bin/squeezelite
                sudo chmod a+x /usr/bin/squeezelite
                sudo systemctl start squeezelite
            else
                echo "File checksum failed. Don't trust downloaded file. Continue with v$sqver."
            fi
            cd; rm -r ~/tmpdownload
        fi
    fi
fi

# install volume control daemon?
read -p 'Do you want to adjust CamillaDSP volume from Material Skin? [N/y]: ' volume
if [[ "$volume" =~ ^([yY])$ ]]; then
    wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/installvolumelms2cdsp.sh -P ~/camilladsp
    /bin/bash ~/camilladsp/installvolumelms2cdsp.sh
    rm ~/camilladsp/installvolumelms2cdsp.sh
fi

# check if we have services up running
echo '----------------------------------'
if sudo systemctl is-active --quiet squeezelite ; then
    echo 'Check Squeezelite is running: OK'
else
    echo 'Check Squeezelite is running: FAIL'
fi
if sudo systemctl is-active --quiet camilladsp ; then
    echo 'Check CamillaDSP is running: OK'
else
    echo 'Check CamillaDSP is running: FAIL'
fi
if sudo systemctl is-active --quiet camillagui ; then
    echo 'Check CamillaGUI is running: OK'
else
    echo 'Check CamillaGUI is running: FAIL'
fi
echo '----------------------------------'

echo ''
echo 'Finished - Please reboot and then enjoy music from the headphones out on your RPi'
echo ''
echo 'CamillaDSP v2 now support selecting sound card from a drop down list under the Devices tab.'
myip=$(hostname -I)
echo "Hyperlink to CamillaDSP: http://${myip//[[:space:]]/}:5000"