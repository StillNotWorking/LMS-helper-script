#!/usr/bin/env python
# Adjust CPU speed based on whenever Squeezelite is Playing or Paused
# Altering between scaling_governors performance and ondemand
# Version 0.0.1 - https://github.com/StillNotWorking/LMS-helper-script
#
# syntax: cpuspeed {player mac} {lms ip} {lms cli port} [-v] verbose is optional
# how to install dependences: pip install telnetlib3

import sys, telnetlib3, asyncio, os

DEBUG = False
usage = "Usage: {} [player mac] [lms ip] [lms cli port 9090] -v (only verbose is optional)".format(sys.argv[0])

# asign arguments to variables
if len(sys.argv) >= 4:
    # print strings from CLI to console
    if '-v' in sys.argv:
        DEBUG = True

    # Player address
    #player = 'd8:3a:dd:46:ef:04'
    player = sys.argv[1]
    if ':' in player:
        # ASCII (URL) encode mac address
        player = player.replace(':', '%3A')
    # LMS address and port
    lmsa = sys.argv[2]
    #lmsp = '9090'
    lmsp = sys.argv[3]
else:
    print('Error - Missing argument!', flush=True)
    print(usage, flush=True)
    sys.exit()

if DEBUG:
    print(usage, flush=True)
    print('---------------------------------------------------')
    print("Player MAC address: {}".format(player.replace('%3A', ':')))
    print("LMS address: {0}  LMS CLI port: {1}".format(lmsa,lmsp), flush=True)
    print('---------------------------------------------------')

async def shell(reader, writer):

    # start subscription for status changes
    writer.write(player + ' subscribe play,pause\r')

    while True:
        # read stream
        outp = await reader.read(50)
        if not outp:
            # End of File
            break

        if DEBUG:
            print("CLI output: " + outp, flush=True)

        outp = outp.replace(player + ' ', '')

        # LMS CLI subscription output
        if any(x in outp for x in ('pause 0', 'play')):
            os.system("sudo sh -c 'echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'")
            if DEBUG:
                print('PLAY', flush=True)
        elif any(x in outp for x in ('pause 1', 'pause', 'stop')):
            os.system("sudo sh -c 'echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'")
            if DEBUG:
                print('PAUSE', flush=True)

        if DEBUG:
            os.system("sudo cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor")
            #os.system("sudo cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_cur_freq")

loop = asyncio.get_event_loop()
coro = telnetlib3.open_connection(lmsa, lmsp, shell=shell)
reader, writer = loop.run_until_complete(coro)
loop.run_until_complete(writer.protocol.waiter_closed)
