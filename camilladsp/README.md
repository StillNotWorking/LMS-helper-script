## CamillaDSP version 2 install script for RPi-OS Lite 64-bit
Intention with this script is to have RPi up running with Squeezelite and CamillaDSP ready to play 2 channel audio from the LMS system.

The headphone output on the RPi are used as initial audio output. Your real DAC can be configured from drop down list in CamillaGUI web page later on.

You need a ready running RPi with latest **RPi-OS Lite 64 bit** on your network. Follow instruction here: https://www.raspberrypi.com/software/
Script should function on **RPi5** and other Debian style distributions with the limitation that the initial output DAC in CamillaDSP configuration might not match the hardware.

Log on to your RPi with a terminal of chose.
Then simply copy & paste the line below into your terminal window and press `Enter`.
```bash
cd ~/ && wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/installcamilladsp.sh && bash ./installcamilladsp.sh


```

When install is finished reboot the RPi and start playing music from your LMS system.

To access CamillaDSP open a web browser with adress `[IP adress to RPi:5005]`

Configuration files for CamillaDSP version 2 are not compatible with previous version. New back-end from v2.1.0 let us now import part of the configuration. If the system already had an older install this script move old files to `/home/{USER}/camilladsp_{TIME]` directory.

***NOTE: If you already have a DAC configured and this had you disable local sound with `#dtparam=audio=on` in `/boot/config.txt` there will be no sound from the headphone out.***

***New in version 2.1.1***
+ Install new back-end v2.1.0
+ Now use Henrik Enquists (HE) install script for CamillaDSP and all of her dependencies. Only additional dependency installed to RPi-OS Lite is 'git'.
+ Version numbering will from now on follow HEs install script with an added character to different local changes.
+ CamillaDSP GUI port default to 5005 can now be changed from install dialog. Used to be port 5000 pre v2.1.1
+ Installation directory can optionally be given as argument. Else default to logged-in users home directory as before.
+ Changed from wget to curl to keep visualizen more uniform with HEs script.
+ Option to upgrade to now official Squeezelite v2.0.0.1465, Debian package are currently at 1.9.9
***New in version 2.0.3***
+ CamillaDSP v2.0.3
***New in version 2.0.1a***
+ Now detect previous install done with current and earlier revision of this script and opt to keep existing CamillaDSP v2 congirurations/filters and coefficients. Keep in mind script still install and start CamillaDSP with at known functioning configuration where output are set to headphone jack.
+ Now automatically edit service files to reflect logged-in user. No need for manually editing.
+ Option to bypass OS upgrade. If selcted now do `apt upgrade` rather than `apt full-upgrade`
+ Option to install daemon to control CamillaDSP volume from LMS - volumelms2cdsp.py
+ Option to install Squeezelite v2.0.0.1465 test version from sourceforge.net. Download are SHA1 and MD5 hash tested before install.

## Configure Playback Device (DAC)
From the CamillaGUI web page click the `Devices` tab and select your `Playback device` from the dropdown list.

## What is CamillaDSP
It's a tool to create audio processing pipelines for applications such as active crossovers or room correction. Sqeezelite's PCM stream goes to Alsa Loopback where CamillaDSP picks it up and do high quality FP64 digital processing before passing it on to desired output.
If the connected DAC is an asynchronous USB device CamillaDSP has the option to control the speed of the input buffer by adjusting alsa pitch. In practise the DAC is now controlling the speed of the data stream.

https://www.diyaudio.com/community/threads/camilladsp-cross-platform-iir-and-fir-engine-for-crossovers-room-correction-etc.349818/

https://github.com/HEnquist/camilladsp

https://github.com/HEnquist/camillagui-backend/blob/master/README.md

## Filters
Script also download a few EQ filters for demonstration if one don't opt to keep existing files from previous install.

## Trouble shooting
Common pitfalls if ran on a Debian computer with other hardware than RPi.
Edit the `Playback Device` under `Devices` tab and click `Save to File`. 

Run `aplay -l` from terminal to list available playback devices.

Default install use SqueezeliteEQ.yml as its initial configuration. Where RPi3 and RPi4 will output to hw:CARD=Headphones,DEV=0

## Remove install
```bash
# Copy paist all code
sudo systemctl stop camillagui
sudo systemctl stop camilladsp
sudo systemctl stop squeezelite
sudo rm /etc/systemd/system/camillagui.service
sudo rm /etc/systemd/system/camilladsp.service
sudo rm /usr/bin/camilladsp*
sudo systemctl daemon-reload
sudo rm -r ~/camilladsp
sudo apt remove squeezelite

# dependencies used pre v2.1.1, new install make use of Python virtual env
sudo pip3 uninstall git+https://github.com/HEnquist/pycamilladsp.git@v2.0.0
sudo pip3 uninstall git+https://github.com/HEnquist/pycamilladsp-plot.git@$v2.0.0
sudo apt remove git python3-pip python3-aiohttp python3-jsonschema python3-numpy python3-matplotlib

```
## User running the daemons
There are four service files that tell the system which user services are initialized with.
Default from the Debian install Squeezelite will run as root. While CamillaDSP, CamillaGUI and VolumeLMS2CDSP run as user logged in when it first where installed. This is due to some Python libryas for security purposes are located in user home directory. From v2.1.1 install make use of virtual install for Python dependencies.

See examples below if you like to change this. Alter `{USER}` to your preferd user name.
```bash
~$ sudo nano /etc/systemd/system/camilladsp.service
~$ sudo nano /etc/systemd/system/camillagui.service
~$ sudo nano /etc/systemd/system/squeezelite.service
~$ sudo nano /etc/systemd/system/volumelms2cdsp.service

ExecStart=/usr/bin/camilladsp -s /home/pi/camilladsp/statefile.yml -o /home/pi/camilladsp/camilladsp.log -l error -p 1234

[Service]
User={USER}
ExecStart=/usr/bin/python3 /home/{USER}/camilladsp/gui/main.py

# then run these commands with the correct file name for the file that where altered.
sudo systemctl daemon-reload
sudo systemctl start camilladsp
sudo systemctl enable camilladsp

```
