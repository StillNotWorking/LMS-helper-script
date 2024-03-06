#!/bin/bash
# 2.1.1 - https://github.com/StillNotWorking/LMS-helper-script
# Scriptet for RPi-OS Lite 64-bit, should work on most Debian style distros
# From v2.1.1 now use official install script but also add alsa loopback,
#   daemon and startup configuration with demo filter configuration
# Configuration files used by this install:
#   /etc/systemd/system/camilladsp.service
#   /etc/systemd/system/camillagui.service
#   /etc/systemd/system/volumelms2cdsp.service (optional)
#   /etc/init.d/squeezelite
#   /etc/default/squeezelite
#   /camilladsp/gui/config/camillagui.yml
#   /etc/modules-load.d/aloop.conf
#   /etc/asound.conf

# version number for Henriks full venv install:
full_install_version="v2.1.1"

# latest Sqeezelite update
sqliteversion="squeezelite-2.0.0.1465-aarch64.tar.gz"

# to visulize URL to CamillaDSP GUI
myip=$(hostname -I)

# find RPi board version, avoid 'null byte in input' 
if test -f /sys/firmware/devicetree/base/model; then
    model=""
    while IFS= read -r -d '' substring || [[ $substring ]]; do
        model+="$substring"
    done </sys/firmware/devicetree/base/model
fi 

# By default CamillaDSP will install its configuration directory, GUI and back-end 
# into logged-in user's home directory. Service files will be edited accordingly

user=${SUDO_USER:-${USER}} # return correct user even when script run as sudo

if [ -z $1 ]; then
    INSTALL_ROOT="$HOME/camilladsp"
else
    INSTALL_ROOT=$1
fi

if [[ $HOME == "/root" ]]; then
    echo "Not recommended to install as 'root' user. Leave out 'sudo', use 'bash $0'"
    exit 1
fi

# take user input before we start install
echo ''; echo "Hi $user"
echo "This will install CamillaDSP with configuration and backend into $INSTALL_ROOT directory on your $model"
read -p 'Press [Enter] to continue or [N] to exit: ' ready
if [[ "$ready" =~ ^([nN])$ ]]; then exit 0; fi

# option to change the GUI port from default 5005
port=5005
echo ''; echo 'Type in port number CamillaDSP GUI should bind to:'
echo "URL used in the web browser 'http://${myip//[[:space:]]/}:$port'"
read -p 'Press [Enter] to use default port 5005: ' -i "$port" -e guiport
guiport=${guiport:-"$port"}

# found existing install, opt to keep existing configs
if test -d $INSTALL_ROOT; then
    read -p 'Keep existing configurations and coefficients? [Y/n]:' keep
    if [[ ! "$keep" =~ ^([nN])$ ]]; then keep="True"; fi
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

# clean up pre v2.0.3 install script
if test -f /usr/bin/camilladsp; then
    sudo rm /usr/bin/camilladsp
fi

# opt out if user already know system are up to date
read -p 'Do you want to upgrade operating system? Recommended! [Y/n]' os
if [[ ! "$os" =~ ^([nN])$ ]]; then
    sudo apt update
    sudo apt upgrade -y
fi

echo '****** Install Squeezelite and backend dependencies ******'
sudo apt install squeezelite git

# Squeezelite configuration
cd
echo "Download: https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/squeezelite"
curl -LJO https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/squeezelite
sudo mv -b $HOME/squeezelite /etc/default/squeezelite
sudo chown root:root /etc/default/squeezelite

echo '****** Install CamillaDSP ******'
# keep existing install with config and filters for reference
if test -d $INSTALL_ROOT; then
    backuptime=$(date +%y%m%d%H%m%s)
    mv $INSTALL_ROOT $HOME/camilladsp_$backuptime
fi

# We leave it to Henrik Enquist to take care of the
# actual install of CamillaDSP and its dependencies
cd
if test -f full_install_venv.sh; then
    rm full_install_venv.sh
fi
echo "Download: https://github.com/HEnquist/camilladsp-setupscripts/releases/download/$full_install_version/full_install_venv.sh"
curl -LJO https://github.com/HEnquist/camilladsp-setupscripts/releases/download/$full_install_version/full_install_venv.sh
if [ $? -ne 0 ]; then
    echo 'ERROR - Failed to download install script:'
    echo "https://github.com/HEnquist/camilladsp-setupscripts/releases/download/$full_install_version/full_install_venv.sh"
    exit 1
fi
source full_install_venv.sh $INSTALL_ROOT

# functioning config/filter file for the 1st run of CamillaDSP
cd $INSTALL_ROOT/configs/
echo "Download: https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/SqueezeliteEQ.yml"
curl -LJO https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/SqueezeliteEQ.yml
cp $INSTALL_ROOT/configs/SqueezeliteEQ.yml $INSTALL_ROOT/default_config.yml

# keep existing configs and coefficients or download demo files
if [[ "$keep" == "True" ]]; then
    # keep existing
    cp -R $HOME/camilladsp_$backuptime/configs $INSTALL_ROOT/
    cp -R $HOME/camilladsp_$backuptime/coeffs $INSTALL_ROOT/
else
    # download filter/configs and coefficients files for demo
    cd $INSTALL_ROOT/configs/
    echo "Download: https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/SqueezeliteEQ_07.yml"
    curl -LJO https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/SqueezeliteEQ_07.yml
    cd $INSTALL_ROOT/coeffs/
    echo "Download: https://raw.githubusercontent.com/HEnquist/camilladsp/master/filter.txt"
    curl -LJO  https://raw.githubusercontent.com/HEnquist/camilladsp/master/filter.txt
fi

# alsa configuration - asound.conf
cd $INSTALL_ROOT/temp
echo "Download: https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/asound.conf"
curl -LJO https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/asound.conf
sudo mv -b asound.conf /etc/asound.conf

# alsa loopback - aloop.conf
cd $INSTALL_ROOT/temp
echo "Download: https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/aloop.conf"
curl -LJO https://raw.githubusercontent.com/HEnquist/camilladsp-config/master/aloop.conf
sudo mv -b aloop.conf /etc/modules-load.d/aloop.conf
sudo modprobe snd-aloop

# download service file
echo "Download: https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camilladsp.service"
cd $INSTALL_ROOT/temp
curl -LJO https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camilladsp.service
sudo mv -b $INSTALL_ROOT/temp/camilladsp.service /etc/systemd/system/camilladsp.service
sudo chown root:root /etc/systemd/system/camilladsp.service

# edit service file with correct user and path to home directory
servicefile='/etc/systemd/system/camilladsp.service'
# 'g' at the end = replace every instace of 'home/pi' with $INSTALL_ROOT
key='ExecStart='
sudo sed -i -e "/^$key/ s|/home/pi/camilladsp|$INSTALL_ROOT|g" $servicefile
key='User='
sudo sed -i -e "/^$key/ s/pi/$user/" $servicefile
key='Group='
sudo sed -i -e "/^$key/ s/pi/$user/" $servicefile

# we should now have a working CamillaDSP installation without GUI
# start CamillaDSP now so it can create the statefile
sudo systemctl daemon-reload
sudo systemctl start camilladsp

# edit port number and path for CamillaDSP GUI
conffile="$INSTALL_ROOT/gui/config/camillagui.yml"
if [[ ! "$guiport" == "5005" ]]; then 
    key='port: '
    sed -i -e "/^$key/ s/5005/$guiport/" $conffile
fi
key='config_dir: '
sed -i -e "/^$key/ s|~/camilladsp|$INSTALL_ROOT|" $conffile
key='coeff_dir: '
sed -i -e "/^$key/ s|~|$INSTALL_ROOT|" $conffile
key='default_config: '
sed -i -e "/^$key/ s|~|$INSTALL_ROOT|" $conffile
key='statefile_path:'
sed -i -e "/^$key/ s|~|$INSTALL_ROOT|" $conffile
key='log_file: '
sed -i -e "/^$key/ s|~|$INSTALL_ROOT|" $conffile

# download and configure camillagui.service
echo "Download: https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camillagui.service"
cd $INSTALL_ROOT/temp
curl -LJO https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/camillagui.service
sudo mv -b $INSTALL_ROOT/temp/camillagui.service /etc/systemd/system/camillagui.service
sudo chown root:root /etc/systemd/system/camillagui.service

# edit gui service file with user and path to home directory
servicefile="/etc/systemd/system/camillagui.service"
key="ExecStart="
sudo sed -i -e "/^$key/ s|/home/pi/camilladsp|$INSTALL_ROOT|g" $servicefile
key="User="
sudo sed -i -e "/^$key/ s/pi/$user/" $servicefile

# Evaluate Squeezelite version, Debian package are at v1.9.9.1414 
# sourceforge.net list a test version v2.0.0.1465
sudo systemctl stop squeezelite
if test -f /usr/bin/squeezelite; then
    string=$(/usr/bin/squeezelite -?)
    string="${string%%,*}" # keep everything before ','
    sqver="${string#* v}"  # remover 'v' and everthing before = version number
    string="${sqver%%.*}"  # only first char left now

    if [[ "$string" == "1" ]]; then   # asume v1.9.x
        echo "Official Debian Squeezelite package installed are v$sqver"
        read -p "Do you want to sudo systemctl stop squeezeliteSqueezelite to v2.0.0 from sourceforge.net? [N/y] " update
        if [[ "$update" =~ ^([yY])$ ]]; then
            cd $INSTALL_ROOT/temp
            echo "Download: https://sourceforge.net/projects/lmsclients/files/squeezelite/linux/$sqliteversion/download"
            curl -LJO -nv https://sourceforge.net/projects/lmsclients/files/squeezelite/linux/$sqliteversion/download
            if [ $? -ne 0 ]; then
                echo "Failed downloading Squeezelite. Continue with v$sqver"
            else
                # check file hash before unpack and install
                if [[ "$(sha1sum $sqliteversion)" == "dba645abf324987dd2068620d629b18915a56046  $sqliteversion" ]] && [[ "$(md5sum $sqliteversion)" == "0170d04ac75f6748ab8b5a51fb66376d  $sqliteversion" ]]; then
                    echo "SHA1 and SH5 checksum OK - Unpack archive:"
                    tar -xvf $sqliteversion
                    sudo mv -b $INSTALL_ROOT/temp/squeezelite /usr/bin/squeezelite
                    sudo chown root:root /usr/bin/squeezelite
                    sudo chmod a+x /usr/bin/squeezelite
                else
                    echo "File checksum failed. Don't trust downloaded file, continuing with v$sqver."
                fi
            fi
        fi
    fi
fi

# functioning statefile for the 1st run of CamillaDSP
# it seems CamillaDSP will overwrite this file at first run
# hence the need to trick her to first make her own before replacing it
if test -f $INSTALL_ROOT/statefile.yml; then
    sudo systemctl stop camilladsp
    rm $INSTALL_ROOT/statefile.yml
else
    sleep 2
    if test -f $INSTALL_ROOT/statefile.yml; then
        sudo systemctl stop camilladsp
        rm $INSTALL_ROOT/statefile.yml
    fi
fi
# download statefile with active config
echo "Download: https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/statefile.yml"
cd $INSTALL_ROOT
curl -LJO https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/statefile.yml
chmod 644 $INSTALL_ROOT/statefile.yml
# edit path in statefile
key='config_path: '
sudo sed -i -e "/^$key/ s|/home/pi/camilladsp|$INSTALL_ROOT|" $INSTALL_ROOT/statefile.yml

# initialize and start daemons
sudo systemctl daemon-reload
sudo systemctl start camillagui
sudo systemctl enable camillagui
sudo systemctl start camilladsp
sudo systemctl enable camilladsp
sudo systemctl start squeezelite

# install volume control daemon? - best run after services are up running
echo ''
read -p 'Do you want to adjust CamillaDSP volume from Material Skin? [N/y]: ' volume
if [[ "$volume" =~ ^([yY])$ ]]; then
    cd $INSTALL_ROOT/temp
    echo "Download: https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/installvolumelms2cdsp.sh"
    curl -LJO https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/installvolumelms2cdsp.sh
    source $INSTALL_ROOT/temp/installvolumelms2cdsp.sh
    rm $INSTALL_ROOT/temp/installvolumelms2cdsp.sh
fi

# check if we have services up running
echo '--------------------------------------'
if sudo systemctl is-active --quiet squeezelite ; then
    echo '  Check if Squeezelite is running: OK'
else
    echo '  Check if Squeezelite is running: FAIL'
fi
if sudo systemctl is-active --quiet camilladsp ; then
    echo '  Check if CamillaDSP is running: OK'
else
    echo '  Check if CamillaDSP is running: FAIL'
    echo "    Possible reason are missing entry in $INSTALL_ROOT/statefile.yml. From web UI first click tab Files, then click a Star in front of any of the files to activate it. This will update the statefile'
fi
if sudo systemctl is-active --quiet camillagui ; then
    echo '  Check if CamillaGUI is running: OK'
else
    echo '  Check if CamillaGUI is running: FAIL'
fi
echo '--------------------------------------'

# cleanup: delete everything inside temp directory
rm $INSTALL_ROOT/temp/*

echo ''
echo 'Finished! - If RPi3 or RPi4 you should now be able to enjoy music from the headphone output'
echo ''
echo 'CamillaDSP v2 now support selecting sound card from a drop down list under the Devices tab.'

echo "URL to CamillaDSP UI: http://${myip//[[:space:]]/}:$guiport"