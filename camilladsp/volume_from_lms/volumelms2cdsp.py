#!python3
# Adjust CamillaDSP volume from Material Skin
# Version 0.0.1 - https://github.com/StillNotWorking/LMS-helper-script
# syntax: ms2cdsp {player mac} {lms ip} {lms cli port} {camilladsp port} [-v] verbose is optional
# mute not supported

# how to install dependences: pip install telnetlib3

import sys, telnetlib3, asyncio, os, math
from camilladsp import CamillaClient

DEBUG = False
usage = "Usage: {} [player mac] [lms ip] [lms cli port 9090] [camilladsp port 1234] -v (only verbose is optional)".format(sys.argv[0])

# asign arguments to variables
if len(sys.argv) >= 5:
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
    # CamillaDSP back-end port
    cdspport = sys.argv[4]
else:
    print('Error - Missing argument!', flush=True)
    print(usage, flush=True)
    sys.exit()

if DEBUG:
    print(usage, flush=True)
    print('---------------------------------------------------')
    print("Player MAC address: {}".format(player.replace('%3A', ':')))
    print("LMS address: {0}  LMS CLI port: {1}".format(lmsa,lmsp), flush=True)
    print("CamillaDSP back-end port: {}".format(cdspport))
    print('---------------------------------------------------')

def rescale(volumep):
    # max attenuation for CamillaDSP volume slider is -51dB
    # this will rescale 1-100% from LMS to -51-0dB that CamillaDSP like to see
    return (51 * (float(volumep)/100)) + 51 * -1

async def shell(reader, writer):
    volumep = 65   # percent
    volumed = -18  # negative numbers in dB when sent to CDSP)

    # get initial player volume setting from LMS
    writer.write(player + ' mixer volume ?\r')
    outp = await reader.read(45)
    if DEBUG:
        print("Initial volume query: {}".format(outp), flush=True)

    # initial LMS CLI output
    if ' mixer volume ' in outp:
        #subs = player + " mixer volume "
        subs = "{} mixer volume ".format(player)
        volumep = outp.replace(subs,"")
        volumed = rescale(volumep)
        # send volume change to CamillaDSP
        cdsp.volume.set_main(volumed)
        if DEBUG:
            print('Initial volumep = {}'.format(volumep), flush=True)
            print('Initial volumed = {}dB'.format(volumed), flush=True)

    # start subscription for volume changes
    writer.write(player + ' subscribe mixer\r')

    while True:
        # read stream
        outp = await reader.read(50)
        if not outp:
            # End of File
            break

        # LMS CLI subscription output
        if ' mixer volume ' in outp:
            if DEBUG:
                print("CLI output before parsing: {}".format(outp), flush=True)

            # ideally we could use 'rsplit' but it fails when char '%2B' (+) orrurs
            subs = "{} mixer volume ".format(player)
            outp = outp.replace(subs,"")
            outp = outp.replace("%2B", "+")

            # Add or substract button pressed
            if '+' in outp:
                outp = outp.replace("+", "")
                outp = int(volumep) + int(outp)
                if outp > 100:
                    outp = 100
                if DEBUG:
                    print ("Volume add {}dB".format(str(outp)))
            elif '-' in outp:
                outp = outp.replace("-", "")
                outp = int(volumep) - int(outp)
                if outp < 0:
                    outp = 0
                if DEBUG:
                    print ("Volume substract {}dB".format(str(outp)))

            volumep = outp
            volumed = rescale(volumep)

            # send volume change to CamillaDSP
            cdsp.volume.set_main(volumed)

            if DEBUG:
                print("Volume " + str(volumed) + "dB", flush=True)

# Connect to CamillaDSP back-end
cdsp = CamillaClient('127.0.0.1', cdspport)
cdsp.connect()

loop = asyncio.get_event_loop()
coro = telnetlib3.open_connection(lmsa, lmsp, shell=shell)
reader, writer = loop.run_until_complete(coro)
loop.run_until_complete(writer.protocol.waiter_closed)
