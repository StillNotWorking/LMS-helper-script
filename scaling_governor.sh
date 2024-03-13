#!/usr/bin/env bash
# Adjust CPU speed according to time. Run as cron job.
# path: /etc/cron.hourly 
# sudo chmod 755 <filename>

hour=$(date +%-H)

if ((9 <= $hour <= 23)); then
    sudo sh -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
else
    sudo sh -c "echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
fi

exit 0
