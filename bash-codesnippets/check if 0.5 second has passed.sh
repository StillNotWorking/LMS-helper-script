#/usr/sbin/bash

# check if 0.5 second has passed
prev_time=$(date +%s%N)
if (( $(($(date +%s%N) - prev_time)) >= 500000000 ))
then
    prev_time=$(date +%s%N)
    echo "True"
else
    echo "False"
fi
