#!/bin/sh
#########################
# gadget.sh
# Audio Gadget setup
# RpiOS (Debian) / RPi 3+
#########################
#
# Daihedz
# 23/06/10/ 00:00
# https://www.diyaudio.com/community/threads/linux-usb-audio-gadget-rpi4-otg.342070/post-7481991
# PDF: https://www.diyaudio.com/community/attachments/rpi_usb_audio_gadet_howto_231015-pdf.1223963/

### Settings ###
# Directories - !!! must be adapted !!!
CONFIGFS_ROOT=/sys/kernel/config # adapt to your machine
GDG_DIRNAME="UAC2Gadget" # adapt as you like

# Basics - better not to be changed, because values are standard
BCD_DEVICE=0x0100 # v.1.0.0
BCD_USB=0x0200 # USB2
ID_VENDOR=0x1d6b # Linux Foundation
ID_PRODUCT=0x0104 # 0x0104 for Multi Functional Gadget / 0x0101 for Audio Gadget

# Strings - likely/optionally to be adapted (except the first one)
STRG_LANGUAGE=0x409 # no need to adapt - 0x409 is a standard value (for US English)
STRG_MANUFACTURER="DIYAudio" # adapt as you like
STRG_PRODUCT="UAC2Gadget" # adapt as you like
STRG_SERIALNUMBER="000001" # adapt as you like

# Configuration(s) - likely/optionally to be adapted
CONFIGURATION_CNF_1="UAC2Config" # adapt as you like

# Functions - !!! must be adapted to the audio format(s) to be processed !!!
AUDIO_CHANNEL_MASK_CAPTURE=3 # 1=Left 2=Right 3=Stereo 0=disables the device
AUDIO_CHANNEL_MASK_PLAYBACK=3
AUDIO_SAMPLE_RATES_CAPTURE=44100,48000,88200,96000
AUDIO_SAMPLE_RATES_PLAYBACK=44100,48000,88200,96000
AUDIO_SAMPLE_SIZE_CAPTURE=4 # 1 for S8LE / 2 for S16LE / 3 for S24LE / 4 for S32LE
AUDIO_SAMPLE_SIZE_PLAYBACK=4

### Load the required kernel modules (and ev. overlays) ###
# libcomposite
modprobe libcomposite

### create the gadget ###
# create the gadget directory and change into it
cd "${CONFIGFS_ROOT}"/usb_gadget
mkdir -p $GDG_DIRNAME
cd $GDG_DIRNAME

# basics
echo $BCD_DEVICE > bcdDevice
echo $BCD_USB > bcdUSB
echo $ID_VENDOR > idVendor
echo $ID_PRODUCT > idProduct

# strings
mkdir -p strings/$STRG_LANGUAGE
echo $STRG_SERIALNUMBER > strings/$STRG_LANGUAGE/serialnumber
echo $STRG_MANUFACTURER > strings/$STRG_LANGUAGE/manufacturer
echo $STRG_PRODUCT > strings/$STRG_LANGUAGE/product

# configuration(s)
mkdir configs/c.1 # index mandatory for every configuration
mkdir -p configs/c.1/strings/$STRG_LANGUAGE
echo $CONFIGURATION_CNF_1 > configs/c.1/strings/$STRG_LANGUAGE/configuration

# functions
mkdir -p functions/uac2.usb0
echo $AUDIO_CHANNEL_MASK_CAPTURE > functions/uac2.usb0/c_chmask
echo $AUDIO_SAMPLE_RATES_CAPTURE > functions/uac2.usb0/c_srate
echo $AUDIO_SAMPLE_SIZE_CAPTURE > functions/uac2.usb0/c_ssize
echo $AUDIO_CHANNEL_MASK_PLAYBACK > functions/uac2.usb0/p_chmask
echo $AUDIO_SAMPLE_RATES_PLAYBACK > functions/uac2.usb0/p_srate
echo $AUDIO_SAMPLE_SIZE_PLAYBACK > functions/uac2.usb0/p_ssize

# associate functions to configurations
ln -s functions/uac2.usb0 configs/c.1/
# enable the gadget
ls /sys/class/udc > UDC