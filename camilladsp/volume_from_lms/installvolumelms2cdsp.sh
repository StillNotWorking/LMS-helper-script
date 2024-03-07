#!/usr/bin/env bash 
# version 0.0.3 - https://github.com/StillNotWorking/LMS-helper-script
# Forward Volume control from LMS to CamillaDSP 
# Install as daemon om Debian based system
# - test platform where RPi-OS 64-bit Lite
 
# stop daemon if there already exist an old install
if sudo systemctl is-active --quiet volumelms2cdsp ; then
    sudo systemctl stop volumelms2cdsp;
fi

# uninstall and remove
if [[ "$1" == "--remove" ]] || [[ "S1" == "--uninstall" ]]; then
    read -p "Do you want to uninstall and remove VolumeLMS2CDSP? (Y/n): " confirm
    if [[ $confirm == [n] ]]; then exit 0; fi
    sudo systemctl disable volumelms2cdsp
    sudo rm /usr/bin/volumelms2cdsp
    sudo rm /etc/systemd/system/volumelms2cdsp.service
    sudo systemctl daemon-reload
    sudo pip uninstall telnetlib3
    exit 0
fi

echo ''
echo 'This will install a daemon to control volume on CamillaDSP from LMS web UI'
echo 'Which version do you want to install?'
echo '  1: Standard'
echo '  2: LessLoss'
echo '  3: Exit without install'

while true; do
    read -p 'Please select 1-3' confirm
    case $confirm in
        [1]* ) fname="volumelms2cdsp.py"; break;;
        [2]* ) fname="volumelms2llcdsp.py"; break;;
        [3]* ) exit 0;;
        * ) echo 'Please select 1-3';;
    esac
done

if [[ $confirm == [1] ]] ; then fname="volumelms2cdsp.py"; fi
if [[ $confirm == [2] ]] ; then fname="volumelms2llcdsp.py"; fi
if [[ $confirm == [3] ]] ; then exit 0; fi

# we make use of Python virtual env installed with CamillaDSP
if test -d ~/camilladsp; then
    INSTALL_ROOT="$HOME/camilladsp"
else
    read -p 'Input path to CamillaDSP directory: ' INSTALL_ROOT
    str="$INSTALL_ROOT/camillagui_venv"
    if ! test -d $str; then
        echo "ERROR - Not able to locate virtual environment in $str"
        exit 1
    fi
fi

# download files
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/$fname
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/volumelms2cdsp.service

# rename Less Loss version to simplify maintance
if [[ "$fname" == "volumelms2llcdsp.py" ]]; then
    mv volumelms2llcdsp.py volumelms2cdsp.py
fi

# install dependency into CamillaDSPs virtual Python environment
sudo /home/pi/camilladsp/camillagui_venv/bin/pip3 install telnetlib3

echo ''
echo 'Script will try to automatically resolve the following information:'
echo '  Player MAC address - can be found under the information menu'
echo '  LMS server address'
echo '  LMS Command Line Interface (CLI) port number - default on server is 9090'
echo '     can be changed from Server -> Plugins -> Command Line Interface (CLI)'
echo '  CamillaDSP back-end port number - often default to 1234 '
echo ''

# try to resolve mac address for active network card
# limitation: only eth0 and wlan0 are testet

wlup=''; ethup=''; mac=''; selected=0

function infotxt {
    info=''; string=''
    if [[ "$1" == "wlan" ]]; then
        string='wlan0 (wireless)'
        if [[ ! "$ethmac" == "" ]]; then
          info="INFO - eth0 (cable) address: $ethmac"
        fi
    elif [[ "$1" == "eth" ]]; then
        string='eth0 (cable)'
        if [[ ! "$wlmac" == "" ]]; then
            info="INFO - wlan0 (wireless) address: $wlmac"        
        fi
    fi
}

# read status and mac address from system 
if test -f /sys/class/net/wlan0/operstate; then
    wlup=$(< /sys/class/net/wlan0/operstate)
    wlmac=$(< /sys/class/net/wlan0/address)
fi
if test -f /sys/class/net/eth0/operstate; then
    ethup=$(< /sys/class/net/eth0/operstate)
    ethmac=$(< /sys/class/net/eth0/address)
fi

if [[ "wlup" == "up" ]] && [[ "ethup" == "up" ]]; then
    # unlikely but both interfaces active, ask which one to use
    echo 'Which network interface are your Squeezelite player running from?'
    echo "Type [1] for wlan0 $wlmac or [2] for eth0 $ethmac"
    read -p 'Any other key will promt for another address: ' selected
    if [[ $selected == 1 ]]; then
        playermac="$wlmac"
        mac="$wlmac"
        infotxt "wlan"
    elif [[ $selected == 2 ]]; then
        playermac="$ethmac"
        mac="$ethmac"
        infotxt "eth"
    else
        mac=''
    fi
elif [[ "$wlup" == "up" ]]; then
    mac="$wlmac"
    infotxt "wlan"
elif [[ "$ethup" == "up" ]]; then
    mac="$ethmac"
    infotxt "eth"
else
    mac=''
fi

# verify mac address from user input if not already done so from dual network
if [[ "$selected" == "0" ]]; then
    if [[ "$mac" == "" ]]; then
        echo 'Could not resolve address for network card'
        read -p 'Please enter mac address for your Squeezelite player: ' playermac
    else
        # verify that active network card is intended for daily use
        echo "$info"; echo ''
        echo 'Is the computer now connected with the network interface intended for daily use?'
        echo "Press [Enter] to use your now active network interface $string"
        read -p "Or enter another mac address to your Squeezelite player: " -i "$mac" -e playermac
        playermac=${playermac:-"$mac"}
    fi
fi

# Search for media server (LMS):
#   Loop through ip addresses in the arp list and try to open a TCP
#   connetion with the port players normally use to connect with LMS

echo ''
echo 'Searching for media server...'

# tcp port players use to connect with LMS
port=3483

# ping local IP4 multicast seem to update the arp list
ping -c2 224.0.0.1 >/dev/null 2>&1

# extract ip addresses from arp list 
list="127.0.0.1 $(arp -a | awk -F'[()]' '{print $2}')"
exlude='224.0.0 239.255 255.255'       # 7 first chars
opencounter=0

# test tcp connection on each ip address including local host
for ip in $list; do
    if [[ ! "$exlude" =~ .*"${ip:0:7}".* ]]; then
        # start connection in new bash process enable us to use timeout
        status=$(timeout 1 bash -c "</dev/tcp/$ip/$port" >/dev/null 2>&1 && echo "open" || echo "closed")
        if [[ "$status" == "open" ]]; then 
            tmplmsaddr="$ip"
            let opencounter++
        fi
        echo "    $ip:$port - $status"
    fi
done

# take user input for LMS address
# TODO - $opencounter tell if more than one address respond to $port
echo ''
if [[ "$tmplmsaddr" == "" ]]; then
    read -p 'Enter LMS address: ' lmsaddr
else
    echo "Press [Enter] if $tmplmsaddr is the correct address to your"
    read -p 'media server (LMS). Or enter another IP address: ' -i $tmplmsaddr -e lmsaddr
    lmsaddr=${lmsaddr:-"$tmplmsaddr"}
fi

# chech if default CLI port 9090 is active
statuscli=$(timeout 2 bash -c "</dev/tcp/$lmsaddr/9090" >/dev/null 2>&1 && echo "open" || echo "closed")
echo "    $lmsaddr:9090 - $statuscli"
# take user input for LMS port
if [[ "$statuscli" == "closed" ]]; then 
    read -p "Could not resolve LMS CLI port. Enter port number or press [Enter] to still use default 9090: " lmsport
    lmsport=${lmsport:-"9090"}
else
    lmsport="9090"
fi

# chech if default CamillaDSP back-end port 1234 is active
statusbe=$(timeout 2 bash -c "</dev/tcp/127.0.0.1/1234" >/dev/null 2>&1 && echo "open" || echo "closed")
# take user input for back-end port
if [[ "$statusbe" == "closed" ]]; then 
    echo 'Could not resolve CamillaDSP back-end port'
    read -p 'Enter port number or press [Enter] for default 1234: ' cdspport
    cdspport=${cdspport:-"1234"}
else
    cdspport="1234"
fi

# move file to correct location
sudo chmod 755 volumelms2cdsp.py
sudo chown root:root volumelms2cdsp.py
sudo mv -b volumelms2cdsp.py $INSTALL_ROOT/bin/volumelms2cdsp

# build startup string
# ExecStart=/home/pi/camilladsp/camillagui_venv/bin/python3 /usr/bin/volumelms2cdsp 00:00:00:00:00:00 127.0.0.0 9090 1234
servicefile='volumelms2cdsp.service'
key='ExecStart='
startstring="ExecStart=$INSTALL_ROOT/camillagui_venv/bin/python3 $INSTALL_ROOT/bin/volumelms2cdsp "
startstring+="${playermac} "
startstring+="${lmsaddr} "
startstring+="${lmsport} "
startstring+="${cdspport}"

# update service file
#  /^$key/       - '^'  beginning of line should begin with
#  s/.*/string/  - '.*' substitute whole line with string
sudo sed -i -e "/^$key/ s|.*|$startstring|" $servicefile

# edit user and group to user running this script
user=${SUDO_USER:-${USER}}
key='User='
sudo sed -i -e "/^$key/ s/.*/$key$user/" $servicefile
key='Group='
sudo sed -i -e "/^$key/ s/.*/$key$user/" $servicefile

sudo chown root:root volumelms2cdsp.service
sudo chmod 755 volumelms2cdsp.service 
sudo mv -b volumelms2cdsp.service /etc/systemd/system/volumelms2cdsp.service

sudo systemctl daemon-reload
sudo systemctl start volumelms2cdsp
sudo systemctl enable volumelms2cdsp

echo ''
if sudo systemctl is-active --quiet volumelms2cdsp ; then
    echo 'Successful install! volumelms2cdsp seems to be up running.'
else
    echo 'Something went wrong! Daemon volumelms2cdsp not running.'
    echo 'Possible error in start up string'
    echo ''
    echo "diagnose:    'sudo systemctl status volumelms2cdsp' "
    echo "edit config: 'sudo nano /etc/systemd/system/volumelms2cdsp.service' "
fi
exit 0
