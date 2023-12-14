# CamillaDSP version 2 install script for RPi-OS Lite 64-bit

Intention with this script is to have RPi up running with Squeezelite and CamillaDSP ready to play 2 channel audio from the LMS system.

The headphone output on the RPi are used as initial audio output. Your real DAC can be configured from CamillaGUI web page later on.

You need a ready running RPi with latest **RPi-OS Lite 64 bit** on your network. Follow instruction here: https://www.raspberrypi.com/software/
Script should function on **RPi5** despite the missing headphone jack.

Log on to your RPi with a SSH terminal of chose. Recommended user is `pi` (*se bottom of page*).
Then simply copy & paste the line below into your terminal window and press `Enter` on your RPi terminal.
```bash
cd ~/ && wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/installcamilladsp.sh && bash ./installcamilladsp.sh

```

When install is finished reboot the RPi and start playing music from your LMS system.

To access CamillaDSP open a web browser with adress `[IP adress to RPi:5000]`

Configuration files for CamillaDSP version 2 are not compatible with previous version. If the system already had an older install this script move old files to `/home/pi/camilladsp_old` directory.

***NOTE: If you already have a DAC configured and this had you disable local sound with `#dtparam=audio=on` in `/boot/config.txt` there will be no sound from the headphone out.***
# Configure Playback Device (DAC)
From the CamillaGUI web page click the `Devices` tab and select the `Playback device` from the dropdown list.
From this string here is what we will type in the CamillaDSP web configuration box: **hw:Amanero:0:0**
# What is CamillaDSP
It's tool to create audio processing pipelines for applications such as active crossovers or room correction. Sqeezelite's PCM stream goes to Alsa Loopback where CamillaDSP picks it up and do high quality FP64 digital processing before passing it on to desiered output, — typical for a headless RPi a sound card configured with Alsa. 

https://www.diyaudio.com/community/threads/camilladsp-cross-platform-iir-and-fir-engine-for-crossovers-room-correction-etc.349818/

https://github.com/HEnquist/camilladsp

https://github.com/HEnquist/camillagui-backend/blob/master/README.md
# Filters
Script also download a few filters for demonstration.

## NOTE: Installation asume the logged in user is `pi`
If another user than `pi` run the install script there are two service files that need to be edited and services initialized.

Change `{USER}` to your user name.
```
~$ sudo nano /etc/systemd/system/camilladsp.service
ExecStart=/usr/bin/camilladsp -p 1234 /home/{USER}/camilladsp/active_config.yml

~$ sudo nano /etc/systemd/system/camillagui.service
[Service]
User={USER}
ExecStart=/usr/bin/python3 /home/{USER}/camilladsp/gui/main.py

# then run
sudo systemctl daemon-reload
sudo systemctl start camilladsp
sudo systemctl enable camilladsp
sudo systemctl start camillagui
sudo systemctl enable camillagui

```
