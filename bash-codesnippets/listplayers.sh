#!/bin/bash
# List LMS players
if [ $# -eq 0 ]; then
    printf '%s\n' "Error - missing IP address to LMS [IP ADDRESS] [PORT]"
    #LMS_IP=192.168.10.253
    #LMS_PORT=9090
    exit
else
    if [ $# -eq 1 ]; then LMS_PORT=9090; else LMS_PORT=$2; fi
    LMS_IP=$1
fi

# we need telnet client to perform this task
if ! which telnet ; then
    printf '%s\n' "Installing telnet client to communicate with LMS service" ;
    sudo apt install telnet
fi

function telnetlms(){
    # Ask LMS for info about its first 25 players
    # sleep usually work even below 0.1 second
    lmsr=$( { echo "players 0 25"; sleep 0.1;} | telnet $LMS_IP $LMS_PORT )
}
function trimlmsresponse() {
    # replace %3A with :
    lmsr="${lmsr//%3A/:}"
    # replace %20 with space
    lmsr="${lmsr//%20/ }"
}
function getplayercount(){
    llmsr=$lmsr
    llmsr="${llmsr#* count:}"
    playercount="${llmsr% playerindex:0*}"
}
function getsingleplayer(){
    # get all info between two playerindex
    next=$(($1+1))
    llmsr=$lmsr
    # get all info for playeindex:$1
    llmsr="${llmsr#* playerindex:$1 }"
    plmsr="${llmsr% playerindex:$next*}"
}
function getname(){ 
    getsingleplayer $1
    name="${plmsr#* name:}"
    name="${name% seq_no:*}"
}
function getfirmware(){ 
    getsingleplayer $1
    firmware="${plmsr#* firmware:}"
    firmware="${firmware% playerindex:*}"
}
function getmac(){
    getsingleplayer $1
    mac="${plmsr#*playerid:}"
    mac="${mac% uuid:*}"
}
function getip(){
    getsingleplayer $1
    ip="${plmsr#*ip:}"
    ip="${ip% name:*}"
    # trim off port used on player
    ip="${ip%:*}"
}
function getmodelname(){
    getsingleplayer $1
    modelname="${plmsr#*modelname:}"
    modelname="${modelname% power:*}"   
}
function createmenu(){
    # create and print numbered list
    clear
    printf '\n%s\n' " Select player [1-$playercount]"
    printf '%s\n' "------------------------------------------------------------------------"
    for ((i=0;i<=playercount-1;i++)); do
        getname $i
        printf '%-18s' " $((i+1)): $name"
        getmodelname $i
        printf '%-27s' "  | model: $modelname";
        getmac $i
        printf '%s\n' "  | MAC: $mac";
    done
    printf '%s\n' " 4: Get me out of here with a graceful exit"
    printf '%s\n' "------------------------------------------------------------------------"

    # wait for user input
    MC=$((playercount+1))
    while true; do
        read -r -s -n1 inst
        case $inst in
            [1-"$MC"]* ) break;;
            * )	echo "Please select option 1 - $MC";;
        esac
    done
    if [ "$inst" = $MC ]; then echo "Bye bye!"; exit 0; fi
    selected=$(($inst-1))
    getname $selected; getmac $selected; getip $selected;
    printf '%s\n' " $name $mac $ip"
    printf '%s\n' "------------------------------------------------------------------------"
}
printf '%s' "Communicating with LMS....."
telnetlms
# this error check is weak and might fail on some system
if [ "$lmsr" = "Trying $LMS_IP..." ]; then 
    echo "Check if IP address and port is correct: $LMS_IP $LMS_PORT" 
    exit 
fi

trimlmsresponse
getplayercount
printf '%s\n' "LMS report having $playercount players";
getfirmware 1
printf '%s\n\n\n' $firmware
createmenu
# echo full telnet return string
echo ""; echo ""; echo $lmsr;

exit
function getuuid(){ echo "uuid $1"; }
function getseq_no(){ echo "seq_no $1"; }
function getmodel(){ echo "model $1"; }
function getpower(){ echo "power $1"; }
function getisplaying(){ echo "isplaying $1"; }
function getdisplaytype(){ echo "displaytype $1"; }
function getisplayer(){ echo "isplayer $1"; }
function getcanpoweroff(){ echo "canpoweroff $1"; }
function getconnected(){ echo "connected $1"; }
