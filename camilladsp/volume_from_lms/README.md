# Adjust volume on CamillaDSP from LMS player
**volumelms2cdsp.py** let you control CamillaDSP volume from LMS user interfaces.

## Principle of operation:
When Player has it volume control set to **Output level is fixed at 100%** from 'Player -> Extra setting -> Audio -> Volume Control' we have the option to repurpose the volume slider.

* *Known limitation are some 100-200ms delay mostly coming from low CPU intensive Python loop with telnetlib3.<sup>1</sup>. Mute are not suported, but both interfaces allow for its implementation.* *

## Install as daemon on RPi-OS (Debian) system
***Before starting the install prepare the following information.***
+ **Player MAC address** - can be found under the information menu
+ **LMS server address**
+ **LMS Command Line Interface (CLI) port number** - default on server is 9090, can be changed from 'Server -> Plugins -> Command Line Interface (CLI)'
+ **CamillaDSP back-end port number** - often default to 1234
 
Log on to your RPi with a SSH terminal application of chose. Then simply copy & paste the line below into your terminal window.

```bash
cd ~/ && wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/camilladsp/volume_from_lms/installvolumelms2cdsp.sh && bash ./installvolumelms2cdsp.sh

```
Make sure the player volume are locked to 100% and Material Skin setting under 'Server -> Plugins -> Material Skin' are set to 'Display standard volume control'
<img src="mssetting.jpg" style="width:48%">

## Control CamillaDSP volume from legacy Logitech devices or classic web UI
Script are dependent on functionality in Material Skin or a plugin that intercept volume changes LMS send to the Player. Known plugins that can intercept are IR Blaster, DenonAVP/AVR Control, and DenonSerial.

## Control other hardware or program from GPIO or USB
Script can be used as insperation to make control over other software and hardware connectet to the computer running the Player.

--------------------------------------------------------------------
1: CLI are usually quite responsive in itself. Initial trail of this idea first tested with bash script showed better performance. A possible more responsive UI can be had if Material Skin send command direcly from its web UI. Although this will exclude legacy Logitech devices to function as controllers.