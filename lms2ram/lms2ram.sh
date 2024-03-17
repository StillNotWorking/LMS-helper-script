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
    sudo apt install inotify-tools -y
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

function check_unclean_exit(){

    # revert back directory name and remove symlink
    [ $DEBUG ] && echo "Check and clean up faulty exit"

    mountpoint -q $ramdiskpath && sudo umount lmsramdisk

    if [ -d $ramdiskpath ]
    then
        sudo rm -rf $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Could not delete mount point directory"
            exit $?
        fi
    fi

    if [ -L $directory ]
    then 
        [ $DEBUG ] && echo "Unlink $directory"
        sudo unlink $directory
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Unlink failed: $directory"
            exit $?
        fi
    fi

    if [ -d $passivedirname ]
    then
        [ $DEBUG ] && echo "Renaming $passivedirname to $directory"
        sudo mv $passivedirname $directory
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Not able to rename $passivedirname"
            exit $?
        fi
    fi

}

function create_ramdisk() {

    [ $DEBUG ] && echo "Create mount point and RAMdisk"

    sudo mkdir $ramdiskpath
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR $? - Not able to create directory $ramdiskpath"
        exit $?
    else
        sudo chown squeezeboxserver:nogroup $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Not able to chown $ramdiskpath"
        fi

        sudo chmod 775 $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Not able to chmod $ramdiskpath"
        fi
    fi

    # when mounted root take ownership of mount point
    [ $DEBUG ] && echo "sudo mount -t tmpfs -o size=$ramsize lmsramdisk $ramdiskpath"
    sudo mount -t tmpfs -o size=$ramsize lmsramdisk $ramdiskpath 
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR $? - Could not mount RAMdisk"
        exit $?
    fi

    #success=$(mount | tail -n 1)
    #if [[ "$success" =~ ^"lmsramdisk on /" ]]
    mountpoint -q $ramdiskpath && [ $DEBUG ] && echo "RAMdisk successfully created"

}

function remove_ramdisk() {

    [ $DEBUG ] && echo "Umount RAMdisk and remove mount point"

    if mountpoint -q $ramdiskpath
    then 
        sudo umount lmsramdisk
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR - Could not umount 'lmsramdisk'"
        fi

        sudo rm -r $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR - Not able to remove directory $ramdiskpath"
        fi
    else
        [ $DEBUG ] && echo "ERROR - $ramdiskpath is not a mount point"
    fi

}

function copy_files(){

    [ $DEBUG ] && echo "Copy new and changed files from RAMdisk to storage"

    if test -d $passivedirname
    then
        IFS='|' read -a fnames <<< "$str"
        for fname in "${fnames[@]}"
        do
            fullpath="$directory/$fname"
            if test -e $fullpath
            then
               [ $DEBUG ] && echo "Copy $fullpath"
               sudo cp -rpf $fullpath $passivedirname
            fi
        done
    fi

}

function do_before_exit() {

    [ $DEBUG ] && echo ''
    [ $DEBUG ] && echo 'We traped 2 [Ctrl+C] and try exit cracefully'

    if sudo systemctl is-active --quiet logitechmediaserver
    then
        [ $DEBUG ] && echo "Stop LMS will close all temporary SQLite files"
        sudo systemctl -q stop logitechmediaserver
        if [ $? -ne 0 ]
        then        
            [ $DEBUG ] && echo "ERROR - Failed stopping LMS to clear SQLite temporary files"
        else
            sleep 0.1
        fi
    fi

    newfilecount=$(sudo find $ramdiskpath/$directorybasename -type f,d,l | wc -l)
    [ $DEBUG ] && echo "Start filecount: $filecount  -  End filecount: $newfilecount"

    copy_files

    # careful not to delete anything we shouldn't we check if directory 
    # actually is a symlink, and if the renamed directory exist
    if [ -L $directory ] && [ -d $passivedirname ]
    then
        [ $DEBUG ] && echo "Remove symbolic link"
        sudo unlink $directory
        [ $DEBUG ] && echo "Change directory name back back to original: $directory"
        sudo mv $passivedirname $directory
    fi

    [ $DEBUG ] && echo "Start Logitech Media Server from standard drive"
    sudo systemctl -q start logitechmediaserver
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR - Failed starting LMS"
        [ $DEBUG ] && echo "try 'sudo systemctl start logitechmediaserver'"
    fi

    [ $DEBUG ] && echo "Set CPU speed back to default 'ondemand'"
    sudo sh -c "echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

    remove_ramdisk

    [ $DEBUG ] && echo "Successful exit $0 PID: $BASHPID"
    exit 0
}

function initiate_program() {

    [ $DEBUG ] && echo "Set CPU scaling governor (speed) to 'performance'"
    sudo sh -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

    [ $DEBUG ] && echo "Stop Logitech Media Server"
    sudo systemctl -q stop logitechmediaserver
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR - Failed stopping LMS"
    else
        sleep 0.2
    fi

    create_ramdisk

    # LMS be stopped before vi count files, directories and links
    filecount=$(sudo find $directory -type f,d,l | wc -l)
    [ $DEBUG ] && echo "Filecount: $filecount"

    [ $DEBUG ] && echo "Copy content from $directory to RAMdisk"
    if mountpoint -q $ramdiskpath
    then
        sudo cp -rp $directory $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Failed copy $directory to RAMdisk"
            exit $?
        else
            [ $DEBUG ] && echo "Verify file and directory count"
            newfilecount=$(sudo find $ramdiskpath/$directorybasename -type f,d,l | wc -l)
            if (( $filecount == $newfilecount ))
            then
                [ $DEBUG ] && echo "OK - $filecount files and directories"
            else
                [ $DEBUG ] && echo "FAIL - $filecount and $newfilecount differ"
                exit 1
            fi
        fi
    else
        [ $DEBUG ] && echo "ERROR - Could not copy content. $ramdiskpath is not a mount point"
    fi

    [ $DEBUG ] && echo "Change name on original $directory to $passivedirname"
    sudo mv $directory $passivedirname
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR $? - Failed changing name on directory"
        exit $?
    fi

    [ $DEBUG ] && echo "Create symlink to RAMdisk"
    sudo ln -s $ramdiskpath/$directorybasename $directory
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR - Could not create symlink"
        exit $?
    else
        sudo chown -h squeezeboxserver:nogroup $directory
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR - Failed chown symlink $directory"
        fi
    fi

    [ $DEBUG ] && echo "Start Logitech Media Server from RAMdisk"
    sudo systemctl -q start logitechmediaserver
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR - Failed starting LMS from RAMdisk"
    fi

}

trap 'do_before_exit' 2  # grafeul exit with Ctrl+C

check_unclean_exit

if [ ! -d $directory ]
then
    [ $DEBUG ] && echo "ERROR - Not able to solve problem with missing $directory"
    exit 1
fi

[ $DEBUG ] && echo "Check directory size $(du -sh $directory)"
[ $DEBUG ] && echo "RAMdisk size is set to: $ramsize"

initiate_program

# let LMS create temp files before vi start monitoring
#sleep 0.2

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