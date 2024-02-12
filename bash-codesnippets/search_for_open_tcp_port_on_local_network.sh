#!/bin/bash
# Loop through ip addresses in the arp list and try to open a 
# TCP connetion with port number given with variable $port

# tcp port players connect to on LMS
port=3483
#port=80

# ping multicast seem to update the arp list
ping -c1 224.0.0.1 >/dev/null 2>&1

# extract only ip addresses from arp and test tcp connection on each one
for ip in $(arp -a | awk -F'[()]' '{print $2}'); do
    # start in new bash process to be able to time out
    status=$(timeout 1 bash -c "</dev/tcp/$ip/$port" >/dev/null 2>&1 && echo "open" || echo "closed")
    echo "$ip: $status"
done