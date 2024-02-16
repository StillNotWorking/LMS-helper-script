#!/usr/bin/env python
# Adjust CamillaDSP volume from Material Skin
# This version snap volume setting to known coeffiecent that keep
# full resolution when truncated to 24-bit
# Version 0.0.1.ll - https://github.com/StillNotWorking/LMS-helper-script
# syntax: volumelms2llcdsp {player mac} {lms ip} {lms cli port} {camilladsp port} [-v] verbose is optional
# mute not supported
#
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


def lessloss(vol):
    if vol == 0:
        return 0 #  0 dB = 0 coefficient

    # testet with 'sox -v [coeff] [file] -n stats' this array should
    # provide attunation without resolution loss when truncated to 24-bit
    # coefficient resolution 32 steps for each 6dB, total 275 steps down to -51dB
    coeffs=([.984375,.96875,.953125,.9375,.921875,.90625,.890625,.875,.859375,.84375,
             .828125,.8125,.796875,.78125,.765625,.75,.734375,.71875,.703125,.6875,.671875,
             .65625,.640625,.625,.609375,.59375,.578125,.5625,.546875,.53125,.515625,.5,
             .4921875,.484375,.4765625,.46875,.4609375,.453125,.4453125,.4375,.4296875,
             .421875,.4140625,.40625,.3984375,.390625,.3828125,.375,.3671875,.359375,
             .3515625,.34375,.3359375,.328125,.3203125,.3125,.3046875,.296875,.2890625,
             .28125,.2734375,.265625,.2578125,.25,.24609375,.2421875,.23828125,.234375,
             .23046875,.2265625,.22265625,.21875,.21484375,.2109375,.20703125,.203125,
             .19921875,.1953125,.19140625,.1875,.18359375,.1796875,.17578125,.171875,
             .16796875,.1640625,.16015625,.15625,.15234375,.1484375,.14453125,.140625,
             .13671875,.1328125,.12890625,.125,.123046875,.12109375,.119140625,.1171875,
             .115234375,.11328125,.111328125,.109375,.107421875,.10546875,.103515625,
             .1015625,.099609375,.09765625,.095703125,.09375,.091796875,.08984375,
             .087890625,.0859375,.083984375,.08203125,.080078125,.078125,.076171875,
             .07421875,.072265625,.0703125,.068359375,.06640625,.064453125,.0625,
             .0615234375,.060546875,.0595703125,.05859375,.0576171875,.056640625,
             .0556640625,.0546875,.0537109375,.052734375,.0517578125,.05078125,.0498046875,
             .048828125,.0478515625,.046875,.0458984375,.044921875,.0439453125,.04296875,
             .0419921875,.041015625,.0400390625,.0390625,.0380859375,.037109375,.0361328125,
             .03515625,.0341796875,.033203125,.0322265625,.03125,.03076171875,.0302734375,
             .02978515625,.029296875,.02880859375,.0283203125,.02783203125,.02734375,
             .02685546875,.0263671875,.02587890625,.025390625,.02490234375,.0244140625,
             .02392578125,.0234375,.02294921875,.0224609375,.02197265625,.021484375,
             .02099609375,.0205078125,.02001953125,.01953125,.01904296875,.0185546875,
             .01806640625,.017578125,.01708984375,.0166015625,.01611328125,.015625,
             .015380859375,.01513671875,.014892578125,.0146484375,.014404296875,
             .01416015625,.013916015625,.013671875,.013427734375,.01318359375,.012939453125,
             .0126953125,.012451171875,.01220703125,.011962890625,.01171875,.011474609375,
             .01123046875,.010986328125,.0107421875,.010498046875,.01025390625,
             .010009765625,.009765625,.009521484375,.00927734375,.009033203125,.0087890625,
             .008544921875,.00830078125,.008056640625,.0078125,.0076904296875,.007568359375,
             .0074462890625,.00732421875,.0072021484375,.007080078125,.0069580078125,
             .0068359375,.0067138671875,.006591796875,.0064697265625,.00634765625,
             .0062255859375,.006103515625,.0059814453125,.005859375,.0057373046875,
             .005615234375,.0054931640625,.00537109375,.0052490234375,.005126953125,
             .0050048828125,.0048828125,.0047607421875,.004638671875,.0045166015625,
             .00439453125,.0042724609375,.004150390625,.0040283203125,.00390625,
             .00384521484375,.0037841796875,.00372314453125,.003662109375,.00360107421875,
             .0035400390625,.00347900390625,.00341796875,.00335693359375,.0032958984375,
             .00323486328125,.003173828125,.00311279296875,.0030517578125,.00299072265625,
             .0029296875,.00286865234375,.0028076171875])

    # Array above will create max 22-bit numbers. It is possible to
    # create a array with approx 1 dB steps and max 20-bit numbers 
    # based on these coefficients: 
    #    1.0000 .8750 .8125 .7500 .6875 .6250 .5625 .5000
    #    Divide by 2 to obtain the next descending 6dB range
    #
    # Allowing for 23-bit numbers 64 step resolution for each 6dB can be realised
    #    1.0000000 .9921875 .9843750 .9765625 .9687500 .9609375 
    #    .9531250 .9453125 .9375000 .9296875 .9218750 .9140625 
    #    .9062500 .8984375 .8906250 .8828125 .8750000 .8671875 
    #    .8593750 .8515625 .8437500 .8359375 .8281250 .8203125 
    #    .8125000 .8046875 .7968750 .7890625 .7812500 .7734375 
    #    .7656250 .7578125 .7500000 .7421875 .7343750 .7265625 
    #    .7187500 .7109375 .7031250 .6953125 .6875000 .6796875 
    #    .6718750 .6640625 .6562500 .6484375 .6406250 .6328125 
    #    .6250000 .6171875 .6093750 .6015625 .5937500 .5859375 
    #    .5781250 .5703125 .5625000 .5546875 .5468750 .5390625 
    #    .5312500 .5234375 .5156250 .5078125 .5000000
    #
    # Truncate errors should become less obvius at higher attunation
    # Therefore one could minimize array to hold coefficients only for
    # the first -12dB or - 18dB and let the rest of attenuation range 
    # use standard calculation

    # dB to coefficient using pow(10)
    vol=(10 ** (vol/20))

    # find coeff lower than volume
    for idx, coeff in enumerate(coeffs):
        if vol >= coeff:
            break

    # figure out if we should snap to current or previous index
    prev=coeffs[idx-1]
    tlow=float(vol-coeff)
    tprev=float(prev-vol)
    if tlow < tprev:
        vol=float(coeff)
    else:
        vol=float(prev)

    # coefficient to dB
    dB=(math.log10(vol)*20)

    if DEBUG:
        print ("lessloss: factor=" + str(vol) + "  " + str(dB) + " dB")

    # Ideally, we should return coefficient but CamillaDSP wont have it
    #return vol
    return dB


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

        volumep = outp.replace(subs,"") # %
        volumed = rescale(volumep)      # dB
        volumed = lessloss(volumed)     # dB lessloss

        # send volume change to CamillaDSP
        cdsp.volume.set_main(volumed) # dB
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
            volumed = lessloss(volumed)

            # send volume change to CamillaDSP
            cdsp.volume.set_main(volumed) # dB

            if DEBUG:
                print("Volume " + str(volumed) + "dB", flush=True)

# Connect to CamillaDSP back-end
cdsp = CamillaClient('127.0.0.1', cdspport)
cdsp.connect()

loop = asyncio.get_event_loop()
coro = telnetlib3.open_connection(lmsa, lmsp, shell=shell)
reader, writer = loop.run_until_complete(coro)
loop.run_until_complete(writer.protocol.waiter_closed)
