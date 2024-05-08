# ATC is a utilety program for Lyrion Music Server and CamillaDSP #
### Its primary functionality is to minimize the number of stages at which audio is rendered ###
This is achieved by transferring digital volume control from LMS to CamillaDSP and adjusting sample rate in CamillaDSP. Optional resampling profiles can be configured based on the sample rate.

Amplitude control may incorporate features such as replay gain and lessloss<sup>2</sup> using fixed coefficient values to reduce rounding errors when 16-bit audio is truncated to 24-bit.

### Principle of operation ###
When Player has it volume control set to `Output level is fixed at 100%` we have the option to repurpose the volume slider.

Using network socket ATC connects with both Lyrion Music Server and CamillaDSP, functioning as gateway between the two program.
Listening to asynchronous events coming from LMS triggers commands are then sent to CamillaDSP and Squeezelite service. 

Beside mute and volume changes ATC also listen for playlist events. 
When a `playlist open` event occurs, ATC requests metadata for the upcoming track from the Lyrion server.

Then after receiving the `newsong` event, if needed the sample rate configuration on CamillaDSP is altered in its running program memory.
If a resampling profile is identified for a specific sample rate in the ATC configuration, it will subsequently modify the resampling and capture sample rate settings for CamillaDSP as well. 
For instance, one might have profiles tailored for upsampling 44100 and 48000 to any selected rate, incorporating all resampling options supported by CamillaDSP, and maintain the integrity of all other high-resolution formats.

Convolution filters are supported with various sample rates denoted in their file names. Additionally, resampling is feasible with convolution filters, requiring the desired capture sample rate to be included in the filename now.

No file edits or saving occur. Reloading the configuration file in CamillaDSP restores it to its saved state.

### Requirement ###
- Linux Debian type distro with systemd. *Developed and testet with RPi-OS*.
- Squeezelite installed with default daemon control, — as installed with the Debian apt package.
- CamillaDSP installed with full back-end including pyCamilla.

### How to install ###
ATC consist of three files:
- atc.py  The program file, can be installed inside `camilladsp` directory.
- atc.yml Configuration including resampling profiles. Keep it in same directory as program file, else full path must be given as argument at program start.
- atc.service Linux service configuration to run ATC as a service under systemd. Move this file to directory: `/etc/systemd/system/`

For **manual install:** copy paiste each step below. Or download the complete shell script and run it using `bash ./install-atc.sh`. 
Two files require configuration tailored to your system.
```bash
#!/usr/bin/env bash
# Install ATC on Debian style distro v0.0.1 - 05.2024
#
# For this example camilladsp exist inside users home directory. Make changes accordingly!
# ~/ is a shorthand notation representing the user's home directory
#
# Download files:
cd ~/camilladsp
wget https://github.com/StillNotWorking/LMS-helper-script/raw/main/atc/atc.py
wget https://github.com/StillNotWorking/LMS-helper-script/raw/main/atc/atc.yml
wget https://github.com/StillNotWorking/LMS-helper-script/raw/main/atc/atc.service

# Change mode so everyone can execute program:
chmod a+x atc.py

# Edit ATC configuration, please adjust the essential settings
# based on the values provided on the LMS information tab:
#  - IP address to Lyrion Music Server
#  - MAC address to Squeezelite player
nano ~/camilladsp/atc.yml

# Edit ATC service configuration
#  - ExecStart= <edit path to python and ATC program file as needed>
#  - User= <type user name you want the service to run under>
nano ~/camilladsp/atc.service

# Move service file, set ownership and start ATC as a service
sudo mv -b ~/camilladsp/atc.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/atc.service
sudo systemctl daemon-reload
sudo systemctl start atc
```

### Use and configuration ###
From Material Skin menu `Player -> Extra setting -> Audio -> Volume Control` set `Output level is fixed at 100%`.

From Material Skin menu `Server -> Plugins - Material Skin`set `Fixed volume players` to `Display standard volume control`.

ATC runs silently in the background<sup>1</sup> as a service, requiring no user interaction on the computer running Squeezelite/CamillaDSP. 

The configuration file `atc.yml` contains explanatory comments. Important settings after a new install is found under `network` where Squeezelite player MAC address and Lyrion server address must be set.

In the service configuration file, the user who runs the program and the program path must be set according to your preferences.

ATC is designed to read resampling profiles from the `atc.yml` file as needed. This ensures that changes regarding these profiles take effect immediately without the need to restart the program. All other settings take place after restating ATC like this: `sudo systemctl restart atc`

When convolution filters are utilized, ATC will edit the value for the key `filename`, — responsible for telling CamillaDSP which convolution file to load.
This implies that dedicated convolution files must exist for all expected sample rates, with identical names except for the different sample rates specified within brackets.
In this example current file name is `MyConvFilter[44100].raw`, if the new sample rate is 96000, the sample rate inside the required `[ ]` brackets will be modified to `MyConvFilter[96000].raw`

For convolution filters if CamillaDSP configuration is `resampler: null` track sample rate is used. If resampling is not null convolution filter name will be set to `capture_samplerate`. This ensure resampling profiles can be used with Conv filters.
There is no check to verify whether these files actually exists, so caution should be exercised.

**atc.py should be executed within the Python virtual environment of CamillaGUI**. Simply typing `python atc.py` will normally fail. 
If `camilladsp` directory exist inside user `pi` home directory the start command would look like this:
```bash
/home/pi/camilladsp/camillagui_venv/bin/python /home/pi/camilladsp/atc.py
```
When properly installed as a service, the start command is:
```bash
sudo systemctl start atc
```

### A suggested course of action if something stops functioning ###
If your system starts behaving strangely at any time, such as when plugin functionality or other features cease to work as intended. Before seeking assistance from developers involved with the malfunctioning component, please verify if things align as expected without executing this program.

### CPU speed ###
This option switch CPU scaling governor depending on play or stop/pause mode of Squeezelite.

If one believe stable CPU speed can impact audio quality this option lock CPU to high speed when audio is playing. And then after a few seconds scale back tok `ondemand` when Squeezelite mode is stop/pause, — saving energy and add longevity to the RPi when the music stop.

Testet with RPi3/4/5 with RPi-OS. Not supported on all CPUs nor do all Linux distributions have the commandset.

### Known limitations & quirks ###
- Changing sample rate for convolution filters are limited to only change the name for the convolution file to load. Type nor read/skip are updated.

- Glitches can occur, especially when quickly jumping between multiple sources playlist events are sometimes not sent correcly from LMS. Resulting in wrong replay gain attenuation and/or sample rate. Listening to a playlist normally with multiple sourches seem to function well, — where metadata often are ready 8 seconds before newsong event take place.

- If ATC i started in middle of a song no correct changes take effect until next track.

- Since we are depending on asynchronous events, the next track might start playing before we receive and can react to the event. This could result in stuttering if the sample rate needs to change. An option to insert a short break has been implemented to mitigate this annoyance.

- A quirk with ALSA is the requirement to free up both ends of its audio path before changes can take place. Although CamillaDSP handles this well, we need to stop Squeezelite to also free the input on the loopback card of ALSA. This introduces some issues.  
The logic enabling volume changes is based on us initially locking the volume for the Squeezelite player to 100%. 
When Squeezelite reconnects with LMS, the server will send the player's configuration back to it, including a volume change to 100%.  
To mitigate this, we ignore all volume changes for 3 seconds, then send last know value to LMS. If we send the command too early, LMS will again attempt to force 100%.  
We also added the options to never adjust to 100%. This ensures that user cases where CamillaDSP is the main volume control in the system do not result in blowned up speakers when a glitch occurs. 
We still do not take responsibility for any damage that may occur. **Here, we emphasize that users must evaluate the associated risks themselves**.

- In most normal implementation of replay gain, the changes take place behind the scenes. However, here, we will observe the main volume slider in CamillaGUI adjusting with replay gain changes. 
Current implementation do not have two way control of volume.

- ATC has only been tested with RPi-OS but should function on all Debian distros. If support for macOS or Windows is desired, the primary changes needed would involve replacing all calls to `systemctl` and remove the CPU speed control.

-----------------------------------------------

<sup>1</sup> For troubleshoting the program can be started manually with the `-v` argument for verbose output. Ensure that the service is stopped before manual execution, — like this: `sudo systemctl stop atc`

<sup>2</sup> Less Loss: Minimise the number of bits used to quantize volume control coefficients so that information loss is minimized at truncation stage. In other words, it trades volume control coefficients precision against information loss minimization - https://www.processing-leedh.com/copie-de-presentation  
  This version resolution are 32 steps for each 6dB change down to -51dB as volume slider in CamillaDSP max attenuation.  
  SoX was used to test bit depth `sox -v [coeff] [file] -n stats`  
  Note: If CamillaDSP are configured to do any filter processing there most likely will take place calculation that end in truncating loss anyway.  

