#!/bin/sh
# This script will configure USB gadget with Daihedz device description
# To reconfigure sample rate and format edit /usr/bin/usbgadget

# Create UDC and the DWC2 kernel module overlay
conf="/boot/config.txt"
str="dtoverlay=dwc2,dr_mode=peripheral"
if test -f $conf; then
	if ! grep -q $str $conf ; then
		echo $str | sudo tee -a $conf
	fi
else 
	echo "Not able to create overlay. $conf doesn't exist."
	exit 1
fi

# download device description and move it to /usr/bin
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/USBgadget/usbgadget.sh -P ~/
sudo mv -b ~/usbgadget.sh /usr/bin/usbgadget
sudo chmod u+x /usr/bin/usbgadget
sudo chown root:root /usr/bin/usbgadget

# prepear USB gadget service 
wget https://raw.githubusercontent.com/StillNotWorking/LMS-helper-script/main/USBgadget/usbgadget.service -P ~/
sudo mv -b ~/usbgadget.service /lib/systemd/system/usbgadget.service
sudo chown root:root /lib/systemd/system/usbgadget.service
sudo systemctl daemon-reload
sudo systemctl start usbgadget
sudo systemctl enable usbgadget

echo "Finished installing USB gadget"
echo "Please reboot to allow changes to take effect"