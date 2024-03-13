## Adjust CPU speed based on whenever Squeezelite is playing or paused
cpuspeed.py switch CPU scaling governor depending on play status of Squeezelite
### Principle of operation:
When script is loaded it will have a telnet client connected to LMS Command Line Interface (CLI). Where it subscribe to play, pause messages associated with a given player.
When Squeezelite is playing the CPU scaling governor are changed to ´performance´ (max speed). When status are pause scaling governor switch back to default ´ondemand´
### Why would we want to use it?
If you believe stable CPU speed can impact audio quality this daemon give you the option to lock CPU to high speed only when audio is playing. And then fall back tok ´ondemand´ saving energy and add longevity to the RPi.
### How to install
Python need the ´telnetlib3´ client to function.

First try ´pip install telnetlib3´
If this fail and you have CamillaDSP installed one possibility is to use its virtual environment like this
´~/camilladsp/camillagui_venv/bin/pip3 install telnetlib3´
If you do it like this you should also use the python executable from here rather than the ususal /usr/bin/

With ´telnetlib3´ in place the script can be tested
cpuspeed <squeezelite player mac address> <lms server ip address> <lms server port>
cpuspeed da:32:40:ff:df:a2 192.168.10.10 9090

To run the script as daemon (service) download and move the ´cpuspeed.service´ file to ´/etc/systemd/system/´. Then run 
´´´
sudo chown root:root cpuspeed
sudo chmod 755 cpuspeed

sudo nano /etc/systemd/system/cpuspeed.service
´´´
Edit the file to reflect path to where you have the script stored and the startup string
ExecStart=/usr/bin/python3 /usr/bin/cpuspeed da:32:40:ff:df:a2 192.168.10.10 9090
