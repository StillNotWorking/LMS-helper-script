#!/usr/bin/env bash
# Move LMS database files and plugins to RAMdisk then
# create symlink where the directory used to live on µSD
#
# Monitor files in directory and copy only new and changed 
# files back to µSD card. Not tested but possible cp -u where only
# new and file time is tested could provide similar functionality?
#
# v0.0.1 - 2024.03.15 - https://github.com/StillNotWorking/LMS-helper-script/tree/main

[[ $@ =~ -v ]] && DEBUG=true

if [ ! $(which inotifywait) ]
then
    [ $DEBUG ] && echo "Install missing inotifywait"
    sudo apt install inotify-tools
fi

# copy this directory to RAMdisk and monitor with inotifywait
directory="/var/lib/squeezeboxserver/cache"

# files to exlude from inotifywait monitoring
# spotty and SQLite temporary files
ex="^($directory/spotty/\.tmp.*|$directory/.*\.db-.*)$"

ramsize="2G"
directorypath=$(dirname $directory)      # path to symlink
directorybasename=$(basename $directory) # symlink basename
passivedirname="$directory~"             # rename original directory
ramdiskpath="/mnt/ramdisk"
str=""

[ $DEBUG ] && echo "Check size of $directory:"
[ $DEBUG ] && echo "$(du -sh $directory) while RAMdisk size is set to: $ramsize"

# number of files, directories and links
filecount=$(sudo find $directory -type f,d,l | wc -l)
[ $DEBUG ] && echo "Filecount: $filecount"

function check_unclean_exit(){
    [ $DEBUG ] && echo "Check and clean up faulty exit"
    # revert back directory name and rename symlink
    if [ -L $directory ]
    then 
        [ $DEBUG ] && echo "Unlink $directory"
        sudo unlink $directory || [ $DEBUG ] && echo "ERROR - Unlink failed: $directory"
    fi
    if [ -d $passivedirname ]
    then
        [ $DEBUG ] && echo "Renaming $passivedirname to $directory"
        sudo mv $passivedirname $directory || echo "ERROR - Not able to rename $passivedirname"
    fi
}

function create_ramdisk() {
    [ $DEBUG ] && echo "Create mount point and RAMdisk"
    sudo mkdir $ramdiskpath || echo "ERROR - Not able to create directory $ramdiskpath"
    sudo chmod 775 $ramdiskpath
    sudo mount -t tmpfs -o $ramsize lmsramdisk $ramdiskpath 
    mountpoint -q $ramdiskpath && [ $DEBUG ] && echo "RAMdisk successfully created"
}

function remove_ramdisk() {
    [ $DEBUG ] && echo "Umount RAMdisk and remove mount point"
    if mountpoint -q $ramdiskpath
    then 
        sudo umount lmsramdisk || [ $DEBUG ] && echo "ERROR - Could not umount 'lmsramdisk'"
        sudo rm -r $ramdiskpath || [ $DEBUG ] && echo "ERROR - Not able to remove directory $ramdiskpath"
    else
        [ $DEBUG ] && echo "ERROR - $ramdiskpath is not a mount point"
    fi
}

function copy_files(){
    [ $DEBUG ] && echo "Copy new and changed files from RAMdisk to storage"
    if [ -d $passivedirname ]
    then
        IFS='|' read -a fnames <<< "$str"
        for fname in "${fnames[@]}"
        do
            fullpath="$directory/$fname"
            sudo cp -rp $fullpath $passivedirname
            [ $DEBUG ] && echo "Copy $fullpath"
        done
    fi
}

function do_before_exit() {

    newfilecount=$(sudo find $directory -type f,d,l | wc -l)
    [ $DEBUG ] && echo "Start filecount: $filecount  -  End filecount: $newfilecount"

    [ $DEBUG ] && echo "Stop LMS will close all temporary SQLite files"
    sudo systemctl stop logitechmediaserver

    copy_files

    # careful not delete anything we shouldn't we check if directory 
    # actually is a symlink, and if the renamed directory exist
    if [ -L $directory ] && [ -d $passivedirname ]
    then
        [ $DEBUG ] && echo "Remove symbolic link"
        sudo unlink $directory
        [ $DEBUG ] && echo "Change directory name back back to original: $directory"
        sudo mv $passivedirname $directory
    fi

    remove_ramdisk

    [ $DEBUG ] && echo "Start Logitech Media Server from standard drive"
    sudo systemctl start logitechmediaserver

    [ $DEBUG ] && echo "Set CPU speed back to default 'ondemand'"
    sudo sh -c "echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

    [ $DEBUG ] && echo "Successful exit $0 PID: $BASHPID"
    exit 0
}

function initiate_program() {

    check_unclean_exit

    [ $DEBUG ] && echo "Set CPU scaling governor (speed) to 'performance'"
    sudo sh -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

    [ $DEBUG ] && echo "Stop Logitech Media Server"
    sudo systemctl stop logitechmediaserver

    create_ramdisk

    [ $DEBUG ] && echo "Change name on original $directory"
    sudo mv $directory $passivedirname

    [ $DEBUG ] && echo "Create symlink to RAMdisk"
    ln -s $ramdiskpath $directory

}

trap 'do_before_exit' 2  # grafeul exit with Ctrl+C

initiate_program

[ $DEBUG ] && echo "Start monitoring of files: 'modify, create, delete'"
while read -r line;
do
    line=${line//$directory\//}  # remove path 
    if [[ ! "$str" == *"$line"* ]]
    then
        str="$str$line|"
        [ $DEBUG ] && echo "$str"
        [ $DEBUG ] && echo "${#str} -----------------"
    fi
done < <(inotifywait -mq -e modify,create,delete --recursive $directory --format %w%f --exclude $ex)

# we should never get here
do_before_exit
exit 1