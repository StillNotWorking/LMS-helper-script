#!/usr/bin/env python3
#
# ATC Version 1.0.0beta
#  - Switch sample rate in CamillaDSP using meta data from LMS and 
#  - Adjust CamillaDSP volume from Material Skin including replay gain
#    https://github.com/StillNotWorking/LMS-helper-script
#
# Must run with Camilla GUI virtual environment for access to all dependencies
#    /home/pi/camilladsp/camillagui_venv/bin/python atc.py {'full path/atc.yml'} {-v}
#        If configuration path and filename not given program look for atc.yml
#        in the directory from where the program is executed.
#
# Primary program logic are to listen for asynchronous events comming from LMS CLI.
#    See 'evaluate_cli_response'. We can code events through LMS CLI to trigger this 
#    function like we do by asynchronous sending play and mixer volume commands.
#
# When Squeezelite reconnect with LMS it seems to happen some house keeping at LMS that
#    read player configuration. Where it find it should be locked to 100% and hence set
#    player volume back at 100%. Workaround used in code is to ignore volume events for
#    a few seconds, then send last known volume setting used before restart of Squeezelite.

import socket
import select
import time
import re
import signal
import os
import fcntl
import struct
import sys
import math
import yaml
import subprocess
import threading

from urllib.parse import unquote
from camilladsp import CamillaClient

threads = [] # Non blocking treads used to send delayed commands to LMS
YML = {}     # Hold all program variables loaded from atc.yml

CDSP = None                # Active configuration object we do edits on
CDSP_ORIGINAL_CONF = None  # The original configuration for safe keeping

SAMPLERATE_NEW     = 44100
VOLUME_LMS_PERCENT = 0  # Range 0-100%
GAIN               = 0  # Hold value of either TRACK_REPLAY_GAIN or ALBUM_REPLAY_GAIN
TRACK_REPLAY_GAIN  = 0
ALBUM_REPLAY_GAIN  = 0
VOLUME_LOCK        = time.time()-2  # If higher than current time we ignore volume changes

# used under development to time events
last_keyword_time = time.time()
start_time = 0

DEBUG = False
if '-v' in sys.argv:
    DEBUG = True
    print("DEBUG mode active", flush=True)

usage = "Usage: {} [path to configuration, if not in same directory as program] [-v (verbose)]".format(os.path.basename(sys.argv[0]))



def load_configuration(config_file):
    global YML

    # Check if configuration file exist
    if not config_file:
        print("Error: Configuration file path is not provided.", flush=True)
        sys.exit(1)
    if not os.path.exists(config_file):
        print("Error: Configuration file does not exist.", flush=True)
        sys.exit(1)
    try:
        config_file = os.path.abspath(config_file)
    except Exception as e:
        print("Error:", e, flush=True)
        sys.exit(1)

    # And finaly read the file
    try:
        with open(config_file) as file:
            YML = yaml.safe_load(file)
    except FileNotFoundError:
        print("Error: File not found.", flush=True)
        sys.exit(1)
    except yaml.YAMLError as e:
        print("Error parsing YAML:", e, flush=True)
        sys.exit(1)
    except Exception as e:
        print("An unexpected error occurred:", e, flush=True)
        sys.exit(1)

    # Create data structure to the configuration if file is missing dict
    if 'settings' not in YML:
        YML['settings'] = {}
    if 'network' not in YML:
        YML['network'] = {}
    if 'resampler' not in YML:
        YML['resampler'] = {}

    # As CamillaDSP can take positive values for digital gain we set max positive
    # gain in dB replay gain can operate, as this potentially can be harmful
    # NOTE: There's a possibility that the tag utilizes positive numbers when
    #       negatives were intended.
    if 'max_replay_gain' not in YML['settings'] or YML['settings']['max_replay_gain'] is None:
        YML['settings']['max_replay_gain'] = 0

    # How frequently we check if connection to LMS CLI port is alive
    if 'keepalive_interval' not in YML['settings'] or YML['settings']['keepalive_interval'] is None:
        YML['settings']['keepalive_interval'] = 300

    # If a track is missing the replay gain tag, it could get annoyingly loud
    if 'default_gain' not in YML['settings'] or YML['settings']['default_gain'] is None:
        YML['settings']['default_gain'] = -4.082399653118496

    if 'ignore_max_volume' not in YML['settings'] or YML['settings']['ignore_max_volume'] is None:
        YML['settings']['ignore_max_volume'] = False

    if 'stutter_delay' not in YML['settings'] or not YML['settings']['stutter_delay']:
        YML['settings']['stutter_delay'] = 0

    if ('lms_connection_delay' not in YML['settings'] or YML['settings']['lms_connection_delay'] is None
        or not (0.01 <= YML['settings']['lms_connection_delay'] <= 1)):
        YML['settings']['lms_connection_delay'] = 0.04

    if 'use_track_replay_gain' not in YML['functions'] or YML['functions']['use_track_replay_gain'] is None:
        YML['functions']['use_track_replay_gain'] = False

    if 'use_album_replay_gain' not in YML['functions'] or YML['functions']['use_album_replay_gain'] is None:
        YML['functions']['use_album_replay_gain'] = True

    if YML.get('functions', {}).get('use_album_replay_gain', True) and YML.get('functions', {}).get('use_track_replay_gain', True):
        YML['functions']['use_track_replay_gain'] = False
		
    if 'switch_samplerate' not in YML['functions'] or YML['functions']['switch_samplerate'] is None:
        YML['functions']['switch_samplerate'] = False

    if 'use_lessloss' not in YML['functions'] or YML['functions']['use_lessloss'] is None:
        YML['functions']['use_lessloss'] = False

    if 'use_volume' not in YML['functions'] or YML['functions']['use_volume'] is None:
        YML['functions']['use_volume'] = False

    if 'switch_cpu_speed' not in YML['functions'] or YML['functions']['switch_cpu_speed'] is None:
        YML['functions']['switch_cpu_speed'] = False

    if 'player_mac_address' not in YML['network'] or YML['network']['player_mac_address'] is None:
        YML['network']['player_mac_address'] = '00:00:00:00:00:00'

    if 'lms_address' not in YML['network'] or YML['network']['lms_address'] is None:
        YML['network']['lms_address'] = '127.0.0.1'

    if 'lms_cli_port' not in YML['network'] or YML['network']['lms_cli_port'] is None:
        YML['network']['lms_cli_port'] = 9090

    if 'cdsp_address' not in YML['network'] or YML['network']['cdsp_address'] is None:
        YML['network']['cdsp_address'] = '127.0.0.1'

    if 'cdsp_port' not in YML['network'] or YML['network']['cdsp_port'] is None:
        YML['network']['cdsp_port'] = 1234
   
    # Consider if we later should write configuration back to file
    #with open('config_file', 'w') as file:
    #yaml.dump(yml, file)

    file.close()

    return


def extract_value(data_string, keyword):
    # Fuction is used to return samplerate and replay gain values

    # Add space and url encoded chars ':' making this function non generic
    keyword = " {}%3A".format(keyword)

    # Create pattern to match the keyword followed by a numeric value
    pattern = rf'{keyword}(-?\d+(?:\.\d+)?(?:e-?\d+)?)'

    # Decode bytes object into a string
    decoded_data = data_string.decode()

    matches = re.findall(pattern, decoded_data)

    if matches and is_float(matches[0]):
        return matches[0] #float(matches[0][0])
    else:
        return 0


def set_convolution_filename(dict):

    # Use capture sample rate when resampling is active
    try:
        if dict['devices']['capture_samplerate'] is None:
            samplerate = dict['devices']['samplerate']
        else:
            samplerate = dict['devices']['capture_samplerate']
    except KeyError:
        samplerate = dict['devices']['samplerate']
    
    # Loop through each filter looking for 'Conv'
    for filter_name, filter_data in dict['filters'].items():
        if filter_data.get('type') == 'Conv':
            # Parse the filename value and replace sample rate string between [] brackets
            filename = filter_data['parameters']['filename']
            new_filename = re.sub(r'\[\d+\]', f'[{samplerate}]', filename)

            # Replace the filename with the new filename
            filter_data['parameters']['filename'] = new_filename

    return dict


def set_sr_profile(dict):
    # Edit the CDSP configuration to include resampling profile read from atc.yml.
    # Even though the 'YML' variable already contains this information, we reread 
    # the file to enable editing and utilization of the resample configuration
    # without requiring a restart of this application.

    samplerate = dict['devices']['samplerate']
    
    try:
        with open(CONFIG_FILE) as file:
            profile = yaml.safe_load(file)
    except FileNotFoundError:
        print("Error: File not found.", flush=True)
        sys.exit(1)
    except yaml.YAMLError as e:
        print("Error parsing YAML:", e, flush=True)
        sys.exit(1)
    except Exception as e:
        print("An unexpected error occurred:", e, flush=True)
        sys.exit(1)

    try:
        sr_profile_exists = profile['resampler'][samplerate]
        if DEBUG:
            print(f"Loading resampling profile found for {samplerate}", flush=True)

        dict['devices']['capture_samplerate'] = profile['resampler'][samplerate]['capture_samplerate']

        # Remove 'capture_samplerate' from this dictionary level to mimic CDSP yaml structure
        if 'resampler' in profile and samplerate in profile['resampler']:
            if 'capture_samplerate' in profile['resampler'][samplerate]:
                del profile['resampler'][samplerate]['capture_samplerate']

        # Now copy the profile
        dict['devices']['resampler'] = None  # first clear the dict key
        dict['devices']['resampler'] = profile['resampler'][samplerate]

    except KeyError:  # No profile found for samplerate

        if DEBUG:
            print(f"No matching resampling profile found for {samplerate}", flush=True)
        # 'capture_samplerate' supposed to be of no concern when resampler is None
        dict['devices']['capture_samplerate'] = YML['settings']['default_samplerate'] 
        dict['devices']['resampler'] = None  # clear the key
        
    file.close()
    
    return dict


def set_samplerate(samplerate, caller_id):
    global YML
    global CDSP, CDSP_ORIGINAL_CONF
    global VOLUME_LMS_PERCENT, VOLUME_LOCK

    conf = None
    volume_percent = VOLUME_LMS_PERCENT

    if DEBUG:
        print(f"------------| SET SAMPLE RATE - Caller ID: {caller_id} |------------", flush=True)
        switch_start = time.perf_counter()

    # Get active configuration from CamillaDSP
    try:
        conf = CDSP.config.active()
    except socket.error as e:
        print(f"Error: {e}, will try to reconnect... ID: set_samplerate", flush=True)
        try:
            CDSP = connect_to_cdsp(YML['network']['cdsp_address'],YML['network']['cdsp_port'])
            conf = CDSP.config.active()
        except Exception as e:
            print(f"{e} ID: set_samplerate", flush=True)

    if conf is None:
        # Exit program and leave it to 'systemctl' configuration to restart it
        print("Error: Not able to read active configuration from CamillaDSP. Exiting...", flush=True)
        signal_handler(2, 0)

    # Get current samplerate CamillaDSP is running with
    cdsp_current_samplerate = None
    cdsp_current_samplerate = conf["devices"]["samplerate"]
    
    if cdsp_current_samplerate is not None:
        if is_integer(cdsp_current_samplerate):
            if int(cdsp_current_samplerate) == int(samplerate):
                if DEBUG:
                    print(f"Nothing to do, CamillaDSP and the track playing have matching sample rate {samplerate} Hz", flush=True)
                    switch_end = time.perf_counter()
                    total = switch_end-switch_start
                    print(f"Total elapsed time to evaluate if switch is necessary: {total} seconds\n----------------------------------------------------------------", flush=True)
                return 0
            else:
                print("Switching sample rate from {} to {}".format(cdsp_current_samplerate,samplerate), flush=True)
    
    # Tell LMS to stop playing, song should then start from beginning after sample rate change
    stop_command = "{} stop\n".format(YML['network']['player_mac_address'])
    sock.sendall(stop_command.encode())
    time.sleep(0.08)  # give LMS a moment to pass on the stop command
        
    # Sadly we need to close Squeezelite to free up ALSA to accept new sample rate
    if DEBUG:
        switch_end = time.perf_counter()
        total = switch_end-switch_start
        
        print(f"Retrieved CamillaDSP configuration and sent \'{YML['network']['player_mac_address']} stop\' command to LMS:\n    {total} seconds", flush=True)
        st = time.perf_counter()
        print('Stopping Squeezelite service...', flush=True)
    
    stop_service('squeezelite')

    if DEBUG:
        et = time.perf_counter()
        duration = et-st
        print(f"Squeezelite stopped, duration for this task: {duration} seconds", flush=True)
        print(f"Time so far {(total + duration)} seconds", flush=True)

    # Change settings
    conf['devices']['samplerate'] = samplerate   # set new sample rate
    # Set resample profile if it exist
    conf = set_sr_profile(conf)
    # Alter filename for any convolution filters 
    conf = set_convolution_filename(conf)
            
    if DEBUG:
        print(f"Upload changes: conf['devices']['samplerate'] = {samplerate}", flush=True)

    # Upload new configuration
    try:
        CDSP.config.set_active(conf)
    except socket.error as e:
        print(f"Error: {e} - Not able to upload new configuration to CamillaDSP", flush=True)

    time.sleep(0.03)  # give CamillaDSP a moment to load configuration

    # Get confirmation changes has taken place on CamillaDSP
    confirm_change = None
    confirmation = None
    for _ in range(5):
        confirm_change = CDSP.config.active()
        confirmation = confirm_change['devices']['samplerate']
    
        if confirmation is not None:
            if confirmation == samplerate:
                if DEBUG:
                    print(f"Changes confirmed, new sample rate is {confirmation}", flush=True)
                break
            else:
                if DEBUG:
                    print(f"Could not confirm new configuration on CDSP:{confirmation}, new samplerate:{samplerate}", flush=True)
    
        time.sleep(0.01)  # initial 30ms testet with RPi4 and have approx 80% success, then first loop here is successful

    if DEBUG:
        #print(confirm_change, flush=True)
        print('Starting Squeezelite service...', flush=True)
        st = time.perf_counter()

    # ********* Start Squeezelite *********
    
    VOLUME_LOCK = time.time() + 3  # When Squeezelite reconnect LMS will set volume to 100% 
                                   # therefore we ignore volume events for a short period
    start_service('Squeezelite')

    if DEBUG: 
        et = time.perf_counter()
        duration = et-st
        print(f"Squeezelite started, duration for this task: {duration} seconds", flush=True)

    # A short delay is needed to let Squeezelite player connect with LMS
    # 40ms are testet with RPi5 LMS server and RPi4 Squeezelite player
    if YML['settings']['stutter_delay'] > YML['settings']['lms_connection_delay']:
        if DEBUG:
            print(f"Stutter delay activatet: {YML['settings']['stutter_delay']} seconds", flush=True)
        delay = YML['settings']['stutter_delay']
    else:
        delay = YML['settings']['lms_connection_delay']

    # Asynchronously commands sendt to LMS -> Squeezelite
    send_player_cmd_delayed('play', delay)
    send_player_cmd_delayed(f"mixer volume {volume_percent}", 3.02)

    if DEBUG:
        switch_end = time.perf_counter()
        total = switch_end-switch_start
        print(f"Total elapsed time to switch sample rate where {total} seconds", flush=True)
    
    return samplerate


def rescale(volume_percent):
    # Max attenuation for CamillaDSP volume slider is -51dB
    # Here we rescale 1-100% from LMS to -51-0dB that CamillaDSP like to see
    if is_float(volume_percent):
        return (51 * (float(volume_percent)/100)) + 51 * -1


def adjust_volume(volume_percent, caller_id):
    global YML

    if volume_percent == 100 and YML['settings']['ignore_max_volume']:
        if DEBUG:
            print('Ignoring volume change, 100% is disablet in configuration', flush=True)
        return

    if not YML['functions']['use_volume']:
        if DEBUG:
            print('Ignoring volume change, function is disablet in configuration', flush=True)
        return

    if is_integer(volume_percent):
        volume_decibel = rescale(volume_percent)
    else:
        return

    if DEBUG:
        print(f"Adjust volume {volume_percent} - Caller ID: {caller_id}", flush=True)
        print(f"Attenuation from LMS {volume_percent}%", flush=True)
        print(f"Attenuation before replay gain: {volume_decibel} dB", flush=True)

    if GAIN:
        volume_decibel = float(volume_decibel) + float(GAIN)
        if DEBUG: 
            print(f"Attenuation  with  replay gain: {volume_decibel} dB", flush=True)

    if YML['functions']['use_lessloss']:
        volume_decibel = lessloss(volume_decibel)

    # Send volume change to CamillaDSP
    try:
        CDSP.volume.set_main(volume_decibel)
        if DEBUG:
            print(f"Attenuation sent to CamillaDSP: {volume_decibel} dB", flush=True)
    except Exception as e:
        if DEBUG: 
            print(f"Error: {e}", flush=True)

    return(volume_decibel)


def mute_volume(muted=False):

    if muted:
        CDSP.mute.set_main(True)
        if DEBUG:
            print("Muting CamillaDSP", flush=True)
    else:
        CDSP.mute.set_main(False)
        if DEBUG:
            print("Unmuting CamillaDSP", flush=True)


def evaluate_volume(volume_raw_data):
    global VOLUME_LMS_PERCENT, VOLUME_LOCK

    if DEBUG:
        print(f"Evaluate volume data: {volume_raw_data}", flush=True)

    if VOLUME_LOCK > time.time():
        if DEBUG:
            print(f"Ignoring event, volume lock active {(VOLUME_LOCK - time.time())}")
        return 0

    # Add or Substract button pressed
    if '%2B' in volume_raw_data:              # + add
        volume_raw_data = volume_raw_data.replace("%2B", "")
        if is_integer(volume_raw_data):
            VOLUME_LMS_PERCENT = int(VOLUME_LMS_PERCENT) + int(volume_raw_data)
            if VOLUME_LMS_PERCENT > 100:
                VOLUME_LMS_PERCENT = 100
        if DEBUG:
            print ("Volume add {}%".format(str(volume_raw_data)), flush=True)
    elif '-' in volume_raw_data:              # - substract
        volume_raw_data = volume_raw_data.replace("-", "")
        if is_integer(volume_raw_data):
            VOLUME_LMS_PERCENT = int(VOLUME_LMS_PERCENT) - int(volume_raw_data)
            if VOLUME_LMS_PERCENT < 0:
                VOLUME_LMS_PERCENT = 0
        if DEBUG:
            print ("Volume substract {}%".format(str(volume_raw_data)), flush=True)
    else:
        if is_integer(volume_raw_data):
            VOLUME_LMS_PERCENT = volume_raw_data

    adjust_volume(VOLUME_LMS_PERCENT, 'evaluate_volume')
    
    return VOLUME_LMS_PERCENT


def send_player_cmd_delayed(command='ATC-trigger', wait=1):
    # Send a valid player command, or simply echo string though LMS CLI 
    # to trigger event picked up in 'evaluate_cli_response'
    
    def delayed_execution():
        time.sleep(wait)
        
        if DEBUG:
            print(f"DELAYED COMMAND (non blocking): {command}, wait: {wait}", flush=True)

        cmd = "{} {}\n".format(YML['network']['player_mac_address'],command)
        sock.sendall(cmd.encode())        

    # Create a thread to execute the delayed function
    stop_command = "STOP"
    thread = threading.Thread(target=delayed_execution)
    thread.start()


def is_integer(s):
    try:
        int(s)
        return True
    except ValueError:
        return False


def is_float(s):
    try:
        float(s)
        return True
    except ValueError:
        return False


def evaluate_cli_response(data):
    global YML
    global SAMPLERATE_NEW
    global VOLUME_LMS_PERCENT, VOLUME_LOCK
    global TRACK_REPLAY_GAIN, ALBUM_REPLAY_GAIN, GAIN
    global last_keyword_time, end_time, start_time

    keyword0 = b'mixer volume '
    keyword1 = b'playlist open '
    keyword2 = b'newsong '
    keyword3 = b'songinfo '
    keyword4 = b'mixer muting '
    
    if DEBUG:
        print(f"> > > {unquote(data.decode().strip())}\n< < <", flush=True)

    # ----------| mixer volume |----------
    if keyword0 in data:

        if VOLUME_LOCK < time.time():
            # Extract text after the keyword
            index = data.index(keyword0) + len(keyword0)
            volume_raw_data = data[index:].decode().strip()

            evaluate_volume(volume_raw_data)

        return

    # ----------| playlist open |----------
    elif any(keyword in data for keyword in [keyword1, b'path ']): # keyword1

        current_time = time.time()  # register time used for supressing 2nd open event

        # We only want the first of two instances of 'playlist open'
        # the second instance can hold redirect path for online streams
        if current_time - last_keyword_time > 0.5:
            last_keyword_time = current_time  # set time for this event

            start_time = time.perf_counter()  # timing keyword events open -> newsong

            if b'path ' in data:
                keyword1 = b'path '
                if DEBUG:
                    print(f"Event: {keyword1.decode().strip()}", flush=True)

            # Extract path after the keyword
            index = data.index(keyword1) + len(keyword1)
            next_track_path = data[index:].decode().strip()

            # Build the command string for LMS cli
            command = "{} songinfo 1 100 url:{} tags:T&I&X&Y\n".format(YML['network']['player_mac_address'], next_track_path)
            if DEBUG:
                print(" * Next track path: {}".format(next_track_path), flush=True)
                print(" * Command sent to LMS: {}".format(command), flush=True)

            # Ask LMS to return information about samplerate and replay gain
            # of the upcomming track: With normal online stream we are appox
            # 8-9 seconds ahead of the new song start playing. If user jump to
            # another song we are approx 150-200 ms ahead of the newsong (play) event
            sock.sendall(command.encode())

        return

    # ----------| playlist newsong |----------
    elif keyword2 in data:

        if DEBUG:
            end_time = time.perf_counter()
            elapsed_time = end_time - start_time
            print(f"Time elapsed from playlist open to newsong: {elapsed_time} seconds", flush=True)

        # Adjust volume before switching sample rate let us ignore house keeping signal 
        # sendt from LMS where volume setting is locket to 100 when Squeezelite reconnect
        if GAIN and VOLUME_LOCK < time.time():
            adjust_volume(VOLUME_LMS_PERCENT, 'newsong')
            
        if YML['functions']['switch_samplerate']:
            set_samplerate(SAMPLERATE_NEW, 'newsong')

        # Play event is often missing when Squeezelite reboot
        if YML['functions']['switch_cpu_speed']:
            set_cpu_speed(True) 
            
        return

    # ----------| songinfo (samplerate, replay gain) |----------    
    elif keyword3 in data:

        # Here we collect and evaluate all the data that are 
        # implemented when 'newsong' event orrur under keyword2
        
        track_replay_gain = extract_value(data,'replay_gain')
        album_replay_gain = extract_value(data,'album_replay_gain')
        SAMPLERATE_NEW = int(extract_value(data,'samplerate'))

        # Check if we have sane data. It seems Spotty do not have replay gain tags
        if DEBUG:
            if track_replay_gain == 0 and album_replay_gain == 0 and SAMPLERATE_NEW == 0:
                print('WARNING: Replay gain and sample rate are all emty. Dataset might not be good.', flush=True)

        # Audio format that do not support samplerate like Spotify most likely
        # are missing sample rate tag and therefor return 0 from 'extract_value()'
        if SAMPLERATE_NEW == 0:
            SAMPLERATE_NEW = YML['settings']['default_samplerate'] 

        if is_float(track_replay_gain):
            TRACK_REPLAY_GAIN = track_replay_gain
        
        if is_float(album_replay_gain):
            ALBUM_REPLAY_GAIN = album_replay_gain

        if (not YML['functions']['use_album_replay_gain'] and 
            not YML['functions']['use_track_replay_gain']):
            GAIN = 0
        else:
            if YML['functions']['use_track_replay_gain']:
                if TRACK_REPLAY_GAIN == 0 and ALBUM_REPLAY_GAIN != 0:
                    GAIN = ALBUM_REPLAY_GAIN
                else:
                    GAIN = TRACK_REPLAY_GAIN
 
            if YML['functions']['use_album_replay_gain']:
                if ALBUM_REPLAY_GAIN == 0 and TRACK_REPLAY_GAIN != 0:
                    GAIN = TRACK_REPLAY_GAIN
                else:
                    GAIN = ALBUM_REPLAY_GAIN

            if TRACK_REPLAY_GAIN == 0 and ALBUM_REPLAY_GAIN == 0: 
                GAIN = YML['settings']['default_gain']

            if float(GAIN) > float(YML['settings']['max_replay_gain']):
                GAIN = YML['settings']['max_replay_gain']
        
        if DEBUG:
            print("Use track RG:       ",YML['functions']['use_track_replay_gain'], flush=True)
            print("Use album RG        ",YML['functions']['use_album_replay_gain'], flush=True)
            print("Samplerate:         ", SAMPLERATE_NEW, flush=True)
            print("Track Replay Gain: ", TRACK_REPLAY_GAIN, flush=True)
            print("Album Replay Gain: ", ALBUM_REPLAY_GAIN, flush=True)
            print("Will use gain:     ", GAIN, flush=True)

        return

    # ----------| mixer muting |----------
    elif keyword4 in data:

        # extract mute 0/1 after the keyword
        index = data.index(keyword4) + len(keyword4)
        muted = re.sub(r'\D', '', data[index:].decode().strip())
        muted = int(muted)

        if muted in (0, 1):
            mute_volume(muted)

        return

    # ----------| play, pause 0, ATC-trigger |----------
    elif any(keyword in data for keyword in [b'playlist pause 0', b'playlist play', b'ATC-trigger']):

        if DEBUG:
            if b'ATC-trigger' in data:
                print ('*************************************************** \n  Manuel trigger reveived and run Play event code\n***************************************************',flush=True)
            else:
                print('<< PLAY >>', flush=True)

        # Ask LMS to send current track path, this should trigger an event that update sr and rg
        get_path_command = "{} path ?\n".format(YML['network']['player_mac_address'])
        if DEBUG:
            print(f"COMMAND sendt from Play {get_path_command}", flush=True)
        sock.sendall(get_path_command.encode())
                 
        if YML['functions']['switch_samplerate']:
            set_samplerate(SAMPLERATE_NEW, 'play')

        if GAIN and VOLUME_LOCK < time.time():
            adjust_volume(VOLUME_LMS_PERCENT, 'play')

        if YML['functions']['switch_cpu_speed']:
            set_cpu_speed(True) 
            
        return

    # ----------| stop, pause 1 |----------
    elif any(keyword in data for keyword in [b'playlist pause 1', b'playlist stop', b'playlist pause']):

        if DEBUG:
            if b'pause' in data:
                print('<< PAUSE >>', flush=True)
            else:
                print('<< STOP >>', flush=True)

        # Stop is received also when playlist jump and sample rate changes. Here we send a
        # delayed request for player mode to check if player actually are in stop/pause mode
        send_player_cmd_delayed('mode ?', 10)
        
        return

    # ----------| mode stop/pause |----------        
    elif any(keyword in data for keyword in [b'mode stop', b'mode pause']):

        if DEBUG:
            print('Event: mode stop/pause', flush=True)

        if YML['functions']['switch_cpu_speed']:
            set_cpu_speed(False) 
            
        return


def connect_to_lms(host, port):
    # Connect to Lyrion Music Server command line interface
    while True:
        try:
            sock = socket.create_connection((host, port))
            time.sleep(0.5)
            # Send the subscription command to Lyrion Media Server
            command = 'subscribe mixer,playlist\n'
            sock.sendall(command.encode())           
            return sock
        except ConnectionRefusedError:
            if DEBUG:
                print("Connection failed. Retrying...", flush=True)
            time.sleep(1)


def send_keepalive(sock):
    try:
        sock.sendall(b"keepalive\n")
    except Exception as e:
        if DEBUG:
            print(f"Failed to send keepalive: {e}. Will try to reconnect...", flush=True)
        # Reconnect to the Lyrion Music Server Command Line Interface
        connect_to_lms(YML['network']['lms_address'], YML['network']['lms_cli_port'])


def signal_handler(sig, frame):
    print('', flush=True)
    if DEBUG:
        print(f"Received signal {sig}. Exiting...", flush=True)
    for thread in threads:
        thread.join()
    sock.close()
    sys.exit(0)


def set_cpu_speed(highspeed=False):
    # Testet with RPi-OS on RPi3, RPi4, RPi5
	# macOS and Windows do not support the scaling governor concept
    sg_read_path = "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor"

    if os.path.exists(sg_read_path):

        if highspeed:
            os.system("sudo sh -c 'echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'")
        else:
            os.system("sudo sh -c 'echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'")

        if DEBUG:
            print('Set scaling governor: ', end='', flush=True)
            os.system("sudo cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor")
            if highspeed:
                # CPU use some time before scaling down in steps, no point waiting for it to stabelize 
                print('CPU speed: ',end='', flush=True)
                os.system("sudo cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_cur_freq")

    return


def lessloss(volume_decibel):
    # Function take attunation value in decibel and return nearest value
    # without resolution loss when 16-bit audio are truncated to 24-bit
    # Note: Using a USB DAC most likely truncating taking place are 32-bit and
    #       left to the DAC to truncate furder if needed. Applying any other
    #       calculation, filter or resampling in CDSP could make use of this
    #       function meaningless

    vol = volume_decibel
    
    if vol >= 0:
        if DEBUG:
            if vol > 0:
                msg = 'Algorithm does not support positive values:'
            print(f"LessLoss: coeff=0  0 dB - {msg} {str(vol)}", flush=True)
        return 0 #  0 dB = 0 coefficient

    # First coefficient give -0.13678849060610931 dB
    if -0.07 <= vol <= 0:
        return 0
    if -0.13678849060610931 <= vol <= -0.08:
        return math.log10(0.984375)*20

    # Coeffs testet with 'sox -v [coeff] [file] -n stats' This list should
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

    # List above will create max 22-bit numbers. It is possible to
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
    # Truncate errors if actually a problem should become less obvius
    # at higher attunation. Therefore one could minimize list to hold
    # coefficients only for the first -18dB and let the rest of
    # attenuation range use standard calculation.
    # NOTE: Calculating with float will loose presisission and not able
    #       to create desiered coeffs. Alternative solution using 
    #       constants and integer to calculate coeffs here:
    #       http://snw.lonningdal.no/sox/volumecoeffsfromconst.py

    # Convert dB to coefficient using pow(10)
    if is_float(vol):
        vol=(10 ** (vol/20))
    else:
        if DEBUG:
            print(f"Volume value not float {vol} - ID: lessloss", flush=True)
        return 0

    # Find coeff lower than volume
    for idx, coeff in enumerate(coeffs):
        if vol >= coeff:
            break
        
    # Figure out if we should snap to current or previous index
    prev=coeffs[idx-1]
    tlow=float(vol-coeff)
    tprev=float(prev-vol)
    if tlow < tprev:
        vol=float(coeff)
    else:
        vol=float(prev)

    # Convert back from coefficient to dB
    dB=(math.log10(vol)*20)

    if DEBUG:
        print(f"LessLoss: coeff={str(vol)}  {str(dB)} dB", flush=True)

    # Ideally, we should return coefficient but CamillaDSP wont have it
    #return vol
    return dB


def stop_service(service_name):
    # Stop a service and wait until it is confirmed stopped
    
    stop_result = subprocess.run(["sudo", "systemctl", "stop", service_name], capture_output=True, text=True)
    
    if stop_result.returncode != 0:
        print(f"Failed to stop service '{service_name}': {stop_result.stderr}")
        return "failed"

    time.sleep(0.1)
    # Wait for the service status until it's inactive or failed
    while True:
        status_result = subprocess.run(["systemctl", "status", service_name], capture_output=True, text=True)
        output_lines = status_result.stdout.split('\n')
        for line in output_lines:
            if "Active:" in line:
                status = line.strip().split()[1]
                if status in ["inactive", "failed"]:
                    return status
        time.sleep(0.05)


def start_service(service_name):

    s_name = service_name.lower()
    loop_counter = 0

    while loop_counter < 10:
        result = subprocess.run(["sudo", "systemctl", "start", s_name])
        if result.returncode == 0:
            if DEBUG:
                print(f"Service {service_name} started successfully", flush=True)
            break
        elif result.returncode == 1:
            if DEBUG:
                print("Service start request perhaps repeated too quickly. Retrying...", flush=True)
            time.sleep(.05)
        else:
            if DEBUG:
                print(f"Failed to start service '{service_name}'", flush=True)
            break
        loop_counter += 1


def is_service_running(service_name, try_start=True):
    # Run the systemctl command to check if the service is active

    s_name = service_name.lower()

    try:
        result = subprocess.run(["systemctl", "is-active", s_name], capture_output=True, text=True)

        if result.returncode == 0 and result.stdout.strip() == "active":
            return True
        else:
            if try_start:
                start_service(service_name)
            return f"Service start command issued for {service_name}"
    except Exception as e:
        print(f"Error: {e}, attempting to start {service_name}...", flush=True)


def check_active_audio_system():
    # Run systemctl command to list enabled services
    try:
        output = subprocess.check_output(['systemctl', 'list-unit-files', '--type=service', '--state=enabled'], text=True)
    except subprocess.CalledProcessError:
        # Handle error (e.g., systemctl not found)
        return False
    
    # Define a list of known audio-related systemd services
    audio_services = ["pulseaudio.service", "jackd.service", "alsa-utils.service", "esd.service", "oss.service"]

    # Check if any audio-related services are enabled
    for line in output.splitlines():
        if DEBUG:
            print(line, flush=True)
        for service in audio_services:
            if service in line:
                return True  # Audio system found
    
    return False  # No active audio system found


def connect_to_cdsp(ip, port, retries=5, delay=0.5):
    # Connect to CamillaDSP back-end

    for x in range(retries):
        try:
            if x == (retries-1):
                print('Failed to connect. Will restart CamillaDSP... ID: connect_to_cdsp', flush=True)
                # Restart CamillaDSP ensure it loads with a configuration we didn't mess with
                start_service('CamillaDSP', True)
                time.sleep(0.1)
            cdsp = CamillaClient(ip, port)
            cdsp.connect()
            return cdsp
        except ConnectionRefusedError as e:
            print(f"Can't connect to CamillaDSP, is it running? Error: {e} ID: connect_to_cdsp", flush=True)
            time.sleep(delay)
        except CamillaError as e:
            print(f"CamillaDSP replied with error: {e} ID: connect_to_cdsp", flush=True)
            time.sleep(delay)
        except IOError as e:
            print(f"Websocket is not connected: {e} ID: connect_to_cdsp", flush=True)
            time.sleep(delay)
        except ConnectionError:
            print("Connection to CamillaDSP failed. Retrying...  ID: connect_to_cdsp", flush=True)
            time.sleep(delay)
        else:
            print('Connected to CamillaDSP', flush=True)

    # If all retries fail, raise an exception
    raise ConnectionError("Unable to connect to CamillaDSP. Check configuration.")


def list_active_interfaces():
    active_interfaces = {}
    for interface in socket.if_nameindex():
        interface_name = interface[1]
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            ip_address = socket.inet_ntoa(fcntl.ioctl(sock.fileno(), 0x8915, struct.pack('256s', bytes(interface_name, 'utf-8')))[20:24])
            mac_address = ':'.join(format(b, '02x') for b in fcntl.ioctl(sock.fileno(), 0x8927, struct.pack('256s', bytes(interface_name, 'utf-8')))[18:24])
            active_interfaces[interface_name] = {'ip_address': ip_address, 'mac_address': mac_address}
        except OSError:
            pass

    return active_interfaces



if __name__ == "__main__":

    # Handle exits with more grace
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # List ip and mac addess of local system
    active_interfaces = list_active_interfaces()
    if DEBUG:
        for interface, info in active_interfaces.items():
            print(f"Interface: {interface}, IP Address: {info['ip_address']}, MAC Address: {info['mac_address']}", flush=True)

    # Figure out which configuration file to load at start
    for arg in sys.argv:
        if arg.endswith('.yml'):
            CONFIG_FILE = arg
    if 'CONFIG_FILE' not in locals():
        CONFIG_FILE = 'atc.yml'
        CONFIG_FILE = "{}/{}".format(os.path.dirname(os.path.abspath(__file__)), CONFIG_FILE)
    if DEBUG:
        print(f"  Configuration read from: {CONFIG_FILE}", flush=True)
    load_configuration(CONFIG_FILE)

    # Attempts to start services if down
    sq = is_service_running('Squeezelite', True) 
    cd = is_service_running('CamillaDSP', True)
    if DEBUG:
        print(f"  Is Squeezelite running: {sq}\n  Is CamillaDSP  running: {cd}", flush=True)

    # Look for running audio system other than alsa
    #if check_active_audio_system():
    #    print("An active audio system is detected.")
    #else:
    #    print("No active audio system is detected.")

    if DEBUG:
        print(f"  {usage}", flush=True)
        print('--------------------------------------------------', flush=True)
        print("  Player MAC address: {}".format(YML['network']['player_mac_address'].replace('%3A', ':')), flush=True)
        print("  LMS address: {0}  LMS CLI port: {1}".format(YML['network']['lms_address'],YML['network']['lms_cli_port']), flush=True)
        print("  CamillaDSP back-end port: {}".format(YML['network']['cdsp_port']), flush=True)
        print('--------------------------------------------------', flush=True)

    try:
        # Connect to CamillaDSP back-end
        CDSP = connect_to_cdsp(YML['network']['cdsp_address'], YML['network']['cdsp_port'])

        # Keep original configuration 'safe'
        CDSP_ORIGINAL_CONF = CDSP.config.active()

        if DEBUG:  # we might need them in later versions
            cdsp_config_file_path = CDSP.config.file_path()
            cdsp_general_state_file_path = CDSP.general.state_file_path()
            print(f"Active configuration: {cdsp_config_file_path}", flush=True)
            print(f"Statefile path:     : {cdsp_general_state_file_path}", flush=True)
        # Send a safe startup attenuation to CamillaDSP
        #CDSP.volume.set_main(-24)
    except ConnectionError as e:
        if DEBUG:
            print(f"Error: {e} - ID: __main__", flush=True)
            print("Will retry connecting...", flush=True)
        time.sleep(1)
        #cdsp = connect_to_cdsp(YML['network']['cdsp_address'], YML['network']['cdsp_port'])

    if (YML['functions']['use_album_replay_gain'] or YML['functions']['use_track_replay_gain']):
        GAIN = -6.020599913279624  # Initial value before any real replay gain values exists

    # Connect to the Lyrion Music Server Command Line Interface
    sock = connect_to_lms(YML['network']['lms_address'], YML['network']['lms_cli_port'])

    last_received_time = time.time()  # initialize the keep alive timer

    # First task is to require current volume setting for player
    request_volume_setting = "{} mixer volume ?\n".format(YML['network']['player_mac_address'])
    sock.sendall(request_volume_setting.encode())

    # From here on receive LMS events on the socket continuously
    # if LMS reboot socket will loose connection and we need to reconnect
    while True:
        try:
            # use select to check if the socket is ready for reading
            ready_to_read, _, _ = select.select([sock], [], [], 0)
            if sock in ready_to_read:
                # Check if the socket is still open
                if sock.fileno() != -1:
                    # Receive data until end of transmission is reached
                    data = b''
                    while not data.endswith(b'\n'):
                        chunk = sock.recv(1024)
                        if not chunk:
                            break
                        data += chunk
                    
                    if data:
                        # Enable line below to debug raw return data from LMS CLI
                        # print(data.decode().strip(), flush=True)  
                        evaluate_cli_response(data)      # main program logic
                        last_received_time = time.time() # reset timer
                    else:
                        # No data received, check if it's time to send a keepalive message
                        current_time = time.time()
                        if current_time - last_received_time > YML['settings']['keepalive_interval']:
                            send_keepalive(sock)
                            last_received_time = current_time  # Update the last received time
            else:
                # Socket not ready for reading, do something else or continue
                time.sleep(0.01)  # go do important stuff some other place
        except Exception as e:
            if DEBUG: 
                print(f"Error: {e}, attempting to reconnect with LMS...", flush=True)
            sock.close()
            time.sleep(0.1)
            sock = connect_to_lms(YML['network']['lms_address'], YML['network']['lms_cli_port'])
            last_received_time = time.time()


    # should never reache here in the current implementation
    sock.close()
