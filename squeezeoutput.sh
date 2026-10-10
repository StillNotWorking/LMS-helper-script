#!/bin/bash
# Change Squeezelite output - v.0.0.3 - StillNotWorking 2026-09, 2025-08, 2024-10
# installed at: /usr/bin/
# Alter the output configuration for Squeezelite. Sourced from Material Skin custom menues
# running on server side from /var/lib/squeezeboxserver/prefs/material-skin/actions.json

CONFIGFILE='/etc/default/squeezelite'
SVKEY='SL_SOUNDCARD=' # Support Debian package config used with SysV /etc/init.d/squeezelite startup
KEY='OPTIONS='         # systemmd we have all default options formated on a single line

# Disable CamillaDSP to free up the sound card and prevent auto reload
STATUS=$(systemctl is-active camilladsp)
if [ "$STATUS" == "active" ]; then
  sudo systemctl stop camilladsp
  sudo systemctl disable camilladsp.service
  sudo systemctl daemon-reload
fi

# Script arguments
case $1 in
  adi2)
    SC='hw:CARD=Pro58840xxx,DEV=0'
    ;;
  m7)
    SC='hw:CARD=Amanero,DEV=0'
    ;;
  cdsp)
    SC='hw:CARD=Loopback,DEV=1'
    sudo systemctl enable camilladsp.service
    sudo systemctl daemon-reload
    sudo systemctl start camilladsp
    ;;
  l12)
    SC='hw:Loopback,1,2'
    ;;
  *)
    exit 1
    ;;
esac

# Stop Squeezelite to free up soundcard and prepare for new configuration
sudo systemctl stop squeezelite

# Update Squeezelite configuration file
if grep -q -E "^$KEY" "$CONFIGFILE"; then
    # replace text between '-o[space]' and first right position '[space]-'
    sudo sed -i -E "/^${KEY}/ s|(-o )[^-]*( -)|\1${SC}\2|" "$CONFIGFILE"
elif grep -q -E "^$SVKEY" "$CONFIGFILE"; then
    #  /^$SVKEY/     - beginning of line should begin with
    #  s/.*/string/  - substitute whatever with string
    sudo sed -i -e "/^$SVKEY/ s/.*/$SVKEY$SC/" "$CONFIGFILE"
fi

# Start Squeezelite with new configuration
sudo systemctl start squeezelite

# Troubleshooting tip:
# Edit /etc/default/squeezelite to enable intensive logging by adding
# this to Squeezelite startup string: -f /var/log/squeezelite -d all=debug
# Then type: tail /var/log/squeezeliteafter after trying to start Squeezelite
# 'squeezelite -l' will list output destinations present on the system
