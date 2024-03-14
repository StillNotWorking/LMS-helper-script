#!/usr/bin/env bash
# Adjust CPU speed according to time. Run as cron job.
# path: /etc/cron.hourly or simply edit /etc/crontab for these tasks
# sudo chmod 755 <filename>

hour=$(date +%-H)

if (($hour >= 9 && $hour <= 22)); then
    sudo sh -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
else
    sudo sh -c "echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
fi

exit 0
