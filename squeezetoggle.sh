#!/bin/bash
# Toggle Squeezelite output - v.0.0.1 - StillNotWorking 2023-11
# Inteded use is to toggle between loopback interface with CamillaDSP and
# direct to sound card. Made to easily be changed for other purposes.
# With standard installation only SC2 (your actual sound card should need to be altered)
#
CONFIGFILE='/etc/default/squeezelite'
KEY='SL_SOUNDCARD='
# CamillaDSP ALSA loopback
SC1='hw:CARD=Loopback,DEV=1'
# My hardware DAC
SC2='hw:CARD=Amanero,DEV=0'

# Stop Squeezelite to free up soundcard in case we already are in direct mode
sudo systemctl stop squeezelite

# Now update configuration file to toggle between SC1 and SC2
if [ $(grep -E ^$KEY$SC1 $CONFIGFILE) ]; then
  #  /^$KEY/       - beginning of line should begin with
  #  s/.*/string/  - substitute whatever with string
  sudo sed -i -e "/^$KEY/ s/.*/$KEY$SC2/" $CONFIGFILE
  # Stop CamillaDSP to free up the sound card
  sudo systemctl stop camilladsp
else
  sudo sed -i -e "/^$KEY/ s/.*/$KEY$SC1/" $CONFIGFILE
  # Start CamillaDSP now that we use SC1 (Loopback device)
  sudo systemctl start camilladsp
fi
# Start Squeezelite with new configuration
sudo systemctl start squeezelite

# If needed volume can be adjustet like this where IP=LMS-server and MAC=player
# By default RPi-OS do not have telnet client installed 'sudo apt-get install telnet'
#telnet 192.168.10.253 9090 <<< 'd8:3a:dd:46:ef:04 mixer volume 50'
# CamillDSP use websocket which complicates direct interaction from bash
# There is a little Python script that can be run with:
#python ~/camilladsp/cdspvol.py -6.02 

#cat $CONFIGFILE
# Troubleshooting tip:
# edit '/etc/default/squeezelite' to enable intensive logging
# SB_EXTRA_ARGS="-C 5 -W -f /var/log/squeezelite -d all=debug"
# Then use 'tail /var/log/squeezelite'
# 'squeezelite -l' will list sound cards present on the system
# If USB sound card is not connected or powered off Squeezelite might fail to start.
