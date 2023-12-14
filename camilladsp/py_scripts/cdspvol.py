# CamillaDSP - adjust volume from CLI
# syntax: cdspvol -3.02 [v]
# positiv values has to be typed explicit
import sys
from camilladsp import CamillaClient
cdsp = CamillaClient("127.0.0.1", 1234)
cdsp.connect()
#print("Version: {}".format(cdsp.get_version()))
# no argument return current volume setting
if len(sys.argv) == 1:
    print("Volume: {}".format(cdsp.volume.main()))
else:
    pf = sys.argv[1]
    if pf[0] == "-" or pf[0] == "+":
        cdsp.volume.set_main(sys.argv[1])
    # v for verbose, else changes take place in silence
    if len(sys.argv) == 3:
        if sys.argv[2]=='v' or sys.argv[2]=='V' or sys.argv[2]=='-v' or sys.argv[2]=='-V':
            print("Volume: {}".format(cdsp.volume.main()))
