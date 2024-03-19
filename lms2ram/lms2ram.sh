#!/usr/bin/env bash
# Move cache directory with LMS SQLite files and plugins to RAM-disk
# v0.0.2 - 2024.03.18 - https://github.com/StillNotWorking/LMS-helper-script/tree/main
#
# Usage: RAM disk size in MB, defaul to +20 of directory if missing
#        -v verbose -c disable CPU clock scaling
#
# Monitor files in directory and copy only new and changed 
# files back to µSD card. Not tested but possible cp -u where only
# new and file time is tested could provide similar functionality?
#
# Chalenge is how to know not fill up storage with temporary files
# not used by LMS at next restart. Some are cleared by LMS but not
# all. For now files are only copied back to storage at clean exit.
#
# WARNING - Undersized RAM-disk can cause system crash
# Default RAM disk size directory size +20% can be to small if
# program is run before scanning new local or remote music archive
# Memory seem to be allocated dynamicly on RPI-OS. Where large 
# RAM-disk size doesn't seem to block rest of the memory if there 
# aren't any actually files there to use up the space allocated.
#


# copy this directory to RAM-disk and monitor with inotifywait
directory="/var/lib/squeezeboxserver/cache"

# files to exlude from inotifywait monitoring
# spotty temporay audio stream, SQLite temporary files
ex="^($directory/spotty/\.tmp.*|$directory/.*\.db-.*)$"

arguments="$@"
passivedirname="$directory~"             # rename original directory to...
ramdiskpath="/mnt/ramdisk"               # not all distros use this /mnt path
str=""                                   # used in the inotifywait loop

ramdiskroot=$(dirname $ramdiskpath)      # used to test if ramdiskpath is valid
directorypath=$(dirname $directory)      # path to symlink
directorybasename=$(basename $directory) # symlink basename

prevgov=$(sudo cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)

[[ $arguments =~ v ]] && DEBUG=true

if [[ $arguments =~ h ]]
then
    echo "$0 {size} RAM-disk size in MB. If size not given"
    echo "     default to 20% larger that $directory"
    echo "    -c --cpu      do not alter CPU clock with scaling governor"
    echo "    -h --help     this text"
    echo "    -t --test     write read speed"
    echo "    -v --verbose"
    exit 0
fi

# any number in the arguments is interpreted as RAM disk size
if [[ $arguments =~ [0-9].* ]]
then
    ramsize="${arguments//*[^.0-9]/}"
    ramsize="${ramsize#"${ramsize%%[![:space:]]*}"}"
else
    # default RAM disk size is directory size + 20%
    dus=$(du -s $directory)
    dus="${dus//[!0-9]/}"
    dus=$(( dus / 1024 ))
    dus=$(( dus + (dus * 20) / 100 ))
    ramsize=$dus
fi

if [ $DEBUG ]
then
    FreeRAM_KB=$(grep MemFree /proc/meminfo | awk '{print $2}')
    FreeRAM_MB=$(expr $FreeRAM_KB / 1024)
    #FreeRAM_GB=$(expr $FreeRAM_MB / 1024)

    echo "Free memory: $FreeRAM_MB""MB before RAM-disk is mounted"
    echo "RAM-disk size: $ramsize""MB"
fi

if (( $ramsize > $FreeRAM_MB ))
then
    [ $DEBUG ] && echo 'WARNING - Might run low on program memory and swap file might be used'
fi

if [ ! $(which inotifywait) ]
then
    [ $DEBUG ] && echo 'Install missing inotifywait'
    sudo apt install inotify-tools -y
fi

if [ ! -d $directory ]
then
    [ $DEBUG ] && echo "Check if $directory exist"
    exit 1
fi


function check_unclean_exit(){

    [ $DEBUG ] && echo 'Check and clean up any faulty exit'

    # revert back directory name and remove symlink
    if mountpoint -q $ramdiskpath
    then
        [ $DEBUG ] && echo "CLEANUP - Unmount $ramdiskpath"
        sudo umount lmsramdisk
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Not able to unmount $ramdiskpath"
            exit 1
        fi
    fi

    if [ -d $ramdiskpath ]
    then
        [ $DEBUG ] && echo "CLEANUP - Remove mount point $ramdiskpath"
        sudo rm -rf $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Could not delete mount point directory"
            exit $?
        fi
    fi

    if [ -L $directory ]
    then 
        [ $DEBUG ] && echo 'CLEANUP - Unlink $directory'
        sudo unlink $directory
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Unlink failed: $directory"
            exit $?
        fi
    fi

    if [ -d $passivedirname ]
    then
        [ $DEBUG ] && echo "CLEANUP - Renaming $passivedirname to $directory"
        sudo mv $passivedirname $directory
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Not able to rename $passivedirname"
            exit $?
        fi
    fi

}

function create_ramdisk() {

    if ! test -d $ramdiskroot
    then
        [ $DEBUG ] && echo "ERROR - Check if directory $ramdiskroot exist"
        exit 1
    fi

    [ $DEBUG ] && echo "Create mount point: $ramdiskpath"
    sudo mkdir $ramdiskpath
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR $? - Not able to create directory $ramdiskpath"
        exit $?
    else
        sudo chown squeezeboxserver:nogroup $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Not able to change owner of $ramdiskpath"
        fi

        sudo chmod 775 $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Not able to change access permissions for $ramdiskpath"
        fi
    fi

    # when mounted root will take ownership of mount point
    [ $DEBUG ] && echo 'Mount RAM-disk:'
    ramsizeM="$ramsize""M"
    [ $DEBUG ] && echo "    sudo mount -t tmpfs -o size=$ramsizeM lmsramdisk $ramdiskpath"
    sudo mount -t tmpfs -o size=$ramsizeM lmsramdisk $ramdiskpath 
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR $? - Could not mount RAM-disk"
        exit $?
    fi

    mountpoint -q $ramdiskpath && [ $DEBUG ] && echo "RAM-disk successfully created - $ramsize""MB"

}

function remove_ramdisk() {

    [ $DEBUG ] && echo 'Umount RAM-disk and remove mount point'

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

    # normally we would write and exit as fast as possible
    # wait for 1.5 second could avoid corrupting the file system
    # if exit signal is sent due to power failure
    sleep 1.5 

    _filecount=0

    [ $DEBUG ] && echo 'Copy new and changed files from RAM-disk back to storage'

    if test -d $passivedirname
    then
        IFS='|' read -a fnames <<< "$str"
        for fname in "${fnames[@]}"
        do
            fullpath="$directory/$fname"
            if test -e $fullpath
            then
               (( _filecount++ ))
               [ $DEBUG ] && echo "Copy: $fname"
               sudo cp -rpf $fullpath $passivedirname
            else
                [ $DEBUG ] && echo "Gone: $fname - file or directory no longer exist"
            fi
        done
        [ $DEBUG ] && echo "Total files copied: $_filecount"
        str=""
    fi

}

function do_before_exit() {

    [ $DEBUG ] && echo ' ...we traped an exit signal'
    [ $DEBUG ] && echo 'Will try save new and changed files back to storage'

    if sudo systemctl is-active --quiet logitechmediaserver
    then
        [ $DEBUG ] && echo 'Stop LMS will update and close all temporary files from SQLite, Spotty and others'
        sudo systemctl -q stop logitechmediaserver
        if [ $? -ne 0 ]
        then        
            [ $DEBUG ] && echo 'ERROR - Failed stopping LMS, temporary files might still be open'
        else
            [ $DEBUG ] && echo 'Sleep 0.2 seconds, give LMS some time to clean up temporary files'
            sleep 0.2
        fi
    fi

    newfilecount=$(sudo find $ramdiskpath/$directorybasename -type f,d,l | wc -l)
    [ $DEBUG ] && echo "Start filecount: $filecount  -  End filecount: $newfilecount"

    copy_files

    # careful not to delete anything we shouldn't we check if directory 
    # actually is a symlink, and if the renamed directory exist
    if [ -L $directory ] && [ -d $passivedirname ]
    then
        [ $DEBUG ] && echo "Remove symbolic link: $directory"
        sudo unlink $directory
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR - Failed removing symbolic link $directory"
        fi
        [ $DEBUG ] && echo "Change directory name back to original: $directory"
        sudo mv $passivedirname $directory
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR - Failed renaming $passivedirname"
        fi
    fi

    [ $DEBUG ] && echo 'Start Logitech Media Server from standard drive'
    sudo systemctl -q start logitechmediaserver
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo 'ERROR - Failed starting Logitech Media Server'
        [ $DEBUG ] && echo "try 'sudo systemctl start logitechmediaserver'"
    fi

    if [[ $arguments =~ c ]]
    then
        [ $DEBUG ] && echo "CPU scaling governor still is $prevgov"
    else
        [ $DEBUG ] && echo "Set CPU scaling governor back to $prevgov"
        sudo sh -c "echo $prevgov > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        if [ $? -ne 0 ]
        then
             $DEBUG ] && echo "ERROR - Failed setting back CPU scaling governor to $prevgov"
        fi
    fi

    remove_ramdisk

    [ $DEBUG ] && echo "Successful exit $0 PID: $BASHPID"
    exit 0

}

function initiate_program() {

    if [[ $arguments =~ c ]]
    then
        [ $DEBUG ] && echo 'Will not set CPU scaling governor'
    else
        [ $DEBUG ] && echo "Set CPU scaling governor (clock speed) to 'performance'"
        sudo sh -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    fi
    [ $DEBUG ] && echo "CPU speed: $(sudo cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_cur_freq)"

    [ $DEBUG ] && echo 'Stop LMS will update and close all temporary files from SQLite, Spotty and others'
    sudo systemctl -q stop logitechmediaserver
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR - Failed stopping LMS"
    else
        sleep 0.1  # give LMS some time to delete temporary files
    fi

    create_ramdisk

    # LMS must be stopped before we count files, directories and links
    filecount=$(sudo find $directory -type f,d,l | wc -l)
    #[ $DEBUG ] && echo "Filecount: $filecount"

    [ $DEBUG ] && echo "Copy content from $directory to RAM-disk"
    if mountpoint -q $ramdiskpath
    then
        sudo cp -rp $directory $ramdiskpath
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR $? - Failed copy $directory to RAM-disk"
            exit $?
        else
            [ $DEBUG ] && echo "Verify file and directory count:"
            newfilecount=$(sudo find $ramdiskpath/$directorybasename -type f,d,l | wc -l)
            if (( $filecount == $newfilecount ))
            then
                [ $DEBUG ] && echo "    OK - $filecount files and directories"
            else
                [ $DEBUG ] && echo "    FAIL - $filecount and $newfilecount differ"
                exit 1
            fi
        fi
    else
        [ $DEBUG ] && echo "ERROR - Could not copy content. $ramdiskpath is not a mount point"
    fi

    [ $DEBUG ] && echo "Change name of original $directory to $passivedirname"
    sudo mv -b $directory $passivedirname
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR $? - Failed changing directory name"
        exit $?
    fi

    [ $DEBUG ] && echo "Create symlink to RAM-disk: $directory"
    sudo ln -s $ramdiskpath/$directorybasename $directory
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo "ERROR - Could not create symlink $directory"
        exit $?
    else
        sudo chown -h squeezeboxserver:nogroup $directory
        if [ $? -ne 0 ]
        then
            [ $DEBUG ] && echo "ERROR - Failed changing owner of symlink $directory"
        fi
    fi

}

delay_lms_startup() {

    [ $DEBUG ] && echo 'Let inotifywait have a few seconds to register all files on RAM-disk before starting LMS'
    sleep 2

    [ $DEBUG ] && echo 'Start Logitech Media Server using RAM-disk for SQLite and plugins'
    [ $DEBUG ] && echo ''

    sudo systemctl -q start logitechmediaserver
    if [ $? -ne 0 ]
    then
        [ $DEBUG ] && echo 'ERROR - Failed starting LMS from RAM-disk'
    fi

}

function run_dd_speedtest() {

    sudo sh -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    create_ramdisk

    echo ''
    if test -e /proc/device-tree/model
    then
        model=$(cat /proc/device-tree/model | tr -d '\0')
        echo $model
    fi

    echo ''; echo '------ µSD card Write -------- oflag=direct -------------------'
    sudo dd if=/dev/zero of=/var/lib/squeezeboxserver/delete_me bs=4K count=2K oflag=direct
    echo ''; echo '------ µSD card Write -------- oflag=nocache -------------------'
    sudo dd if=/dev/zero of=/var/lib/squeezeboxserver/delete_me bs=4K count=2K oflag=nocache
    echo ''; echo '------ µSD card Read  -------- iflag=direct -------------------'
    sudo dd of=/dev/zero if=/var/lib/squeezeboxserver/delete_me bs=4K count=2K iflag=direct
    echo ''; echo '------ µSD card Read  -------- iflag=nocache ------------------'
    sudo dd of=/dev/zero if=/var/lib/squeezeboxserver/delete_me bs=4K count=2K iflag=nocache
    
	echo ''; echo '------ RAM disk Write -------- oflag=direct -------------------'
    sudo dd if=/dev/zero of=/mnt/ramdisk/delete_me bs=4K count=2K oflag=direct
    echo ''; echo '------ RAM disk Read  -------- iflag=direct -------------------'
    sudo dd of=/dev/zero if=/mnt/ramdisk/delete_me bs=4K count=2K iflag=direct
    echo ''
    sudo rm /var/lib/squeezeboxserver/delete_me

    remove_ramdisk
    sudo sh -c "echo $prevgov > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

    exit 0

}

# try do a graceful exit when receiving signal
# SIGINT SIGTERM SIGQUIT SIGABRT SIGTERM
trap 'do_before_exit' 1 2 3 6 15

check_unclean_exit

if [ ! -d $directory ]
then
    [ $DEBUG ] && echo "ERROR - Not able to solve problem with missing $directory"
    exit 1
fi

# sub program will exit program from its function
if [[ $arguments =~ t ]]
then
    run_dd_speedtest
fi

[ $DEBUG ] && echo "Directory size: $(du -sh $directory)"

# main program start from here
initiate_program


[ $DEBUG ] && echo "Start monitoring of files: 'modify, create, delete'"
[ $DEBUG ] && echo 'Use [Ctrl+C] to exit: '
[ $DEBUG ] && echo '---------------------'
[ $DEBUG ] && echo ''

# start LMS asynchronously delayed in a new background process
# ensure all file events are captured when LMS first loads
delay_lms_startup &

# this loop is event driven, only when the stream feed 
# a new line with a filename this code is executed
while read -r line;
do

    line=${line//$directory\//}    # remove path

    if [[ ! "$str" == *"$line"* ]] # filter out duplets
    then
        str="$str$line|"
        if [ $DEBUG ]
        then
            IFS='|' read -a fnames <<< "$str"
            echo "$line  (${#fnames[@]})"
        fi
    fi
done < <(inotifywait -mqr -e modify,create,delete $directory --format %w%f --exclude $ex)

# we should never get here
do_before_exit
exit 1
