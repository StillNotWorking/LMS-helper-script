#!/bin/bash
# Easily add USB storage devices to RPi-OS (Debian)
# v.0.0.1 - 2022-08 - passed https://www.shellcheck.net/
# WARNING: script do not attempt to be portable
# verified platform is RPi-OS Lite 32-bit (Bullseye)
# List storage devices from 'blkid' exluding sd with PARTUUID
# or UUID already configured in 'fstab'. For user then to select 
# single partition to mount with automatically added entry to 
# 'fstab' before 'mount -a' are executed. 
# Option to create relative symlink to newly mounted partition 
# in user's home directory + option to create alias to commands
# 'cd [mount point] && ls -l'

#mountdir="/media/"
mountdir="/mnt/"

if [[ ! "$EUID" = 0 ]]; then
	printf '%b\n' "We need root privileges to mount new partition\nPlease run script with sudo" 
	exit
fi

user=$(logname)
cd "/home/$user" || exit 1

# read PARTUUID and UUID from already mounted storage devices
partuuidetc=$(while IFS= read -r line ; do
	if [[  $line =~ "PARTUUID" ]] || [[  $line =~ "UUID" ]]; then
		line="$(cut -f1 -d' ' <<< "$line")"
		line="$(cut -f1 <<< "$line")"
		line="$(cut -f2 -d'=' <<< "$line")"
		echo "$line"
	fi
done </etc/fstab)

# filter connected storage devices not already enabled in fstab
id=$(sudo blkid)
newsd=$(while IFS= read -r line; do
	sd=$(grep '^/dev/sd' <<< "$line")
	if [[ -n "$sd" ]]; then 
		while IFS= read -r uuid; do
			sd=$(grep -v "$uuid" <<< "$sd")
		done <<< "$partuuidetc"
		if [[ -n "$sd" ]]; then echo "$sd"; fi
	fi
done <<< "${id//\"/}")

# create and print numbered list
printf '%s\n' "Select partition to mount using PARTUUID or UUID with default settings:"
printf '%s\n' "-----------------------------------------------------------------------"
if [[ -z $newsd ]]; then 
	printf '%s\n' "No new drives detected. Note if PARTUUID or UUID already registered in fstab these drives will not be listed. [END]"
	exit 0
fi
x=1
while IFS= read -r line; 
	do printf '%s\n' "$x: $line"; ((x++));
done <<< "$newsd"
printf '%s\n' "$x: Exit without doing anything"
printf '%s\n' "-----------------------------------------------------------------------"
printf '%s' "Select [1-$x]: "

# wait for user input
while true; do
    read -r inst
    case $inst in
        [1-"$x"]* ) break;;
        * )	echo "Please select option 1 - $x";;
    esac
done

if [ "$inst" = $x ]; then echo "Bye bye!"; exit 0; fi
printf '%s\n' "-----------------------------------------------------------------------"

# get string from user selection
x=0
while read -r line; do
  ((x++));
  test "$x" = "$inst" && break;
done <<< "$newsd"

# get label from selected partition
if [[ "$line" =~ LABEL=(.*) ]]; then
	label=$(cut -f1 -d' ' <<< "${BASH_REMATCH[1]}")
elif [[ "$line" =~ UUID=(.*) ]]; then
	label=$(cut -f1 -d' ' <<< "${BASH_REMATCH[1]}")
	label="sd${label:(-4)}"
else 
	label="usbsd"
fi
if [[ -z "$label" ]] || [ "$label" = " " ]; then label="usbsd"; fi

# wait for user input
printf '%b\n' "Do you want to mount using label name '$label'?\nPress 'n' to type in another label  [y/n]"
while true; do read -r inst
    case $inst in
        [yY]|[nN]* ) break;;
        * )	echo "Please select option y(es) - n(o)";;
    esac
done

if [ "$inst" = "n" ]; then
	read -r -p "Enter label name for mount point (directory): " label
fi

# '\040' to replace space in fstab and a few other chars !$+@_[[:space:]]
labelfst="$(sed -e "s/!/%21/g;s/\\$/%24/g;s/+/%2B/g;s/@/%40/g;s/_/%5F/g;s/ /\\\040/g" <<< "$label")"

# check if mount point already in use
mountpoint="$mountdir$labelfst/"
fsta=$(cat /etc/fstab)
if [[ "$fsta" =~ $mountpoint ]]; then
	printf '%s\n' "Mount point '$mountpoint' already in use. Please start over using another label."
	printf '%s\n' "Tip: Use 'sudo nano /etc/fstab' to manually edit mount point"
	exit 1
fi
# from selected partition get the PARTUUID, if none found use UUID
if [[ "$line" =~ PARTUUID=(.*) ]]; then
	partuuid=$(cut -f1 -d' ' <<< "${BASH_REMATCH[1]}")
	uuidstr="PARTUUID"
elif [[ "$line" =~ UUID=(.*) ]]; then
	partuuid=$(cut -f1 -d' ' <<< "${BASH_REMATCH[1]}")
	uuidstr="UUID"
else 
	printf '%s\n' "Error - Not able to resolve PARTUUID or UUID from selected partition. Sorry but we have to end here." 
	exit 1
fi

# from selected partition get the filesystem TYPE
if [[ "$line" =~ TYPE=(.*) ]]; then
	type=$(cut -f1 -d' ' <<< "${BASH_REMATCH[1]}")
else 
	printf '%s\n' "Error - Not able to resolve filesystem from selected partition. Sorry but we have to end here." 
	exit 1
fi

# format the string used to mount the partition
mountstr="$uuidstr=$partuuid	$mountpoint	$type	defaults,noatime	0	0"

printf '%s\n' "Make directory $mountpoint (mount point)"
if ! sudo mkdir -p "$mountpoint";
	then printf '%s\n' "Error - Not able to create directory for mount point"; exit; fi
printf '%s\n' "Backup /etc/fstab.backup"
if ! sudo cp /etc/fstab /etc/fstab.backup;
	then printf '%s\n' "Error not able to make backup of '/etc/fstab'"; exit 1; fi
if ! sudo printf '\n%s' "$mountstr" | tee -a /etc/fstab > /dev/null;
	then printf '%s\n' "Error writing to '/etc/fstab'"; exit 1; 
	else printf '%s\n' "New entry to /etc/fstab:"
		 printf '%s\n' "$mountstr"; fi
printf '%s\n' "Mount new storage device using 'mount -a'"
if ! sudo mount -a;
	then printf '%s\n' "Error executing 'sudo mount -a'"; exit 1; fi

# Create Symbolic Links
printf '%s\n' "-----------------------------------------------------------------------"
printf '%s\n' "Do you want to create symbolic link to newly mounted directory? [y/n]"
while true; do read -r inst
    case $inst in
        [yY]|[nN]* ) break;;
        * )	echo "Please select option y(es) - n(o)";;
    esac
done
if [ "$inst" = "y" ]; then
	sym="/home/$user/$labelfst"
	if [[ -f "$sym" ]]; then 
		printf '%s\n' "WARNING: $labelfst already exist. Symlink not created!"
	else
		if ! ln -s -r "$mountpoint" "$sym";
			then printf '%s\n' "Error creating symlink";
		else 
			if [[ -f "$sym" ]]; then 
				printf '%s\n' "Symlink '$label' successfully added"; 
			else
				printf '%s\n' "Error - Creating symlink '$label' failed"; 
			fi
		fi
	fi
fi

# Create alias
printf '%s\n' "-----------------------------------------------------------------------"
printf '%b\n' "Do you want to create an alias (shortcut) to $mountpoint?\nexample of alias could be short command words like 'sd1' 'sd2' 'flash' 'usb'" 
printf '%s' "[y/n] "
while true; do read -r inst
    case $inst in
        [yY]|[nN]* ) break;;
        * )	echo "Please select option y(es) - n(o)";;
    esac
done
if [ "$inst" = "y" ]; then
	read -r -p "Enter alias name: " al
	cd "/home/$user" || exit 1
	if ! printf '\n%s' "alias ""$al""=\"cd $mountpoint && ls -l\"" | tee -a "/home/$user/.bash_aliases" > /dev/null;
		then printf '%s\n' "Error creating alias'"; exit 1;
		else printf '%s\n' "Alias '$al' available at next login"; fi
fi
printf '%s\n\n' "[END]"
exit 0
#inotifywait