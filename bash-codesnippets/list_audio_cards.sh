#!/usr/bin/env bash
# list audio devices by text parsing /proc/asound/cards

tIFS=$IFS; IFS=$'\n'
cards=$(cat /proc/asound/cards)
loopcount=-1

for card in $cards; do
    # only trim lines starting with space and a digit
    if [[ "$card" =~ ^[[:space:]][0-9] ]]; then
        shortname=${card#* \[}               # remove everything before [
        shortname=${shortname% \]:*}         # remove everthing from ]:
        shortname=${shortname//[[:space:]]/} # remove spaces
        ((loopcount++))
        #echo "$loopcount $shortname"
        # format string for use with CamillaDSP
        echo "hw:CARD=$shortname,DEV=0"
    fi
done

IFS=$tIFS
exit 0
