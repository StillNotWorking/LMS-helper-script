#!/usr/bin/env bash
# Move LMS database files and plugins to RAMdisk
# Monitor files in directory and copy only new and changed files back to SD card
# v0.0.1 - 2024.03.15 - https://github.com/StillNotWorking/LMS-helper-script/tree/main

[[ $@ =~ -v ]] && DEBUG=true

if [ ! $(which inotifywait) ]; then
    [ $DEBUG ] && echo "Install missing inotifywait"
    sudo apt install inotify-tools
fi

# directory to link and monitor
directory="/var/lib/squeezeboxserver/cache"

# files to exlude from inotifywait monitoring
# spotty and SQLite temporary files
ex="^($directory/spotty/\.tmp.*|$directory/.*\.db-.*)$"

ramsize="2G"
directorypath=$(dirname $directory)
directorybasename=$(basename $directory) # symlink basename
passivedirname="$directory~"           # rename original directory
ramdiskpath="/mnt/ramdisk"
str=""

[ $DEBUG ] && echo "Check size of $directory:"
[ $DEBUG ] && echo "$(du -sh $directory) while RAMdisk size is set to: $ramsize"

# number of files, directories and links
filecount=$(sudo find $directory -type f,d,l | wc -l)
[ $DEBUG ] && echo "Filecount: $filecount"

function check_unclean_exit(){
    # revert back directory name and rename symlink
    if [ -L $directory ]; then
        [ $DEBUG ] && echo "Unlink $directory"
        sudo unlink $directory || [ $DEBUG ] && echo "ERROR - Unlink failed: $directory"
    fi
    if [ -d $passivedirname ]; then
        [ $DEBUG ] && echo "Renaming $passivedirname to $directory"
        sudo mv $passivedirname $directory || echo "ERROR - Not able to rename $passivedirname"
    fi
}

function create_ramdisk() {
    sudo mkdir $ramdiskpath || echo "ERROR - Not able to create directory $ramdiskpath"
    sudo chmod 775 $ramdiskpath
    sudo mount -t tmpfs -o $ramsize lmsramdisk $ramdiskpath 
}

function create_script(){
    echo ''
#    echo -e '#!/urc/bin env /bash"' # > ramtofile.sh
#    echo -e 'IFS='|' read -a fnames <<< "\$str"' # >> ramtofile.sh
   # for fname in "${fnames[@]}"; do\
   #     echo "$fname"\
   #     fullpath="$directory/$fname"\
   # done") > rmatofile.sh\
}
#create_script;ls -l;exit;
function copy_files(){
    # copy changed files from ramdisk to storage
    #if [ -d $passivedirname ]; then
    IFS='|' read -a fnames <<< "$str"
    for fname in "${fnames[@]}"; do
        echo "$fname"
        fullpath="$directory/$fname"
    done
}

function do_before_exit() {

    newfilecount=$(sudo find $directory -type f,d,l | wc -l)
    [ $DEBUG ] && echo "Start filecount: $filecount  -  End filecount: $newfilecount"

    [ $DEBUG ] && echo "Stop LMS to close all temporary SQLite files"
    sudo systemctl stop logitechmediaserver

    [ $DEBUG ] && echo "Copy files from RAMdisk to µSD card"
    copy_files

    # check if directory is symlink, and if the renamed directory exist
    # if not we are careful not deleting anything
    if [ -L $directory ] && [ -d $passivedirname ] ; then
        [ $DEBUG ] && echo "Remove symbolic link"
        sudo unlink $directory
        [ $DEBUG ] && echo "Change name back back to original: $directory"
        sudo mv $passivedirname $directory
    fi

    [ $DEBUG ] && echo "Unount RAMdisk"
    sudo umount lmsramdisk

    [ $DEBUG ] && echo "Start Logitech Media Server from standard drive"
    sudo systemctl start logitechmediaserver

    [ $DEBUG ] && echo "CPU speed back to default 'ondemand'"
    sudo sh -c "echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

    [ $DEBUG ] && echo "Exit PID: $BASHPID"
    exit 0
}

function initiate_program() {

    [ $DEBUG ] && echo "Check and clean up faulty exit"
    check_unclean_exit

    [ $DEBUG ] && echo "Set CPU scaling governor (speed) to 'performance'"
    sudo sh -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

    [ $DEBUG ] && echo "Stop Logitech Media Server"
    sudo systemctl stop logitechmediaserver

    [ $DEBUG ] && echo "Create RAMdisk"
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