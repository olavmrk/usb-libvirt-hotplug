#!/usr/bin/python3
# origin: https://github.com/darkguy2008/hotplugger
import sys
import signal
import subprocess

print("")
print("Using both an USB 3.0 and an USB 2.0 device (could be a thumb drive,")
print("an audio device or any other simple USB device), plug and unplug the")
print("device in the ports that you are interested for VM passthrough.")
print("")
print("Press Control + C when finished. The app will then print the device")
print("path of the USB ports. Also make sure that 'udevadm' is installed.")
print("")
print("Monitoring USB ports...")

###########################
# This gets the UDEV events
###########################

listout = []


def handle(sig, _):
    if sig == signal.SIGINT:
        print("")


signal.signal(signal.SIGINT, handle)
proc = subprocess.Popen(
    ["udevadm", "monitor", "-k", "-u", "-p", "-s", "usb"], stdout=subprocess.PIPE)

while True:
    line = proc.stdout.readline()
    if not line:
        break
    if line.startswith(b'DEVPATH'):
        listout.append(line)

proc.wait()

######################################
# This gets an unique list of DEVPATHs
######################################



# function to get unique values

def unique(input_list):
    
    # leave only unique entries
    return list(dict.fromkeys(input_list))



# function to remove the netries that are not useful for udev

def remove_unnecessary(input_list):

    # copy to avoid modifying the input list
    output_list = list(input_list)

    # traverse for all elements
    for element in output_list:
        # remove long entries as they are not useful for udev
        for potential_prefix in output_list:     
            if element != potential_prefix and element.startswith(potential_prefix):
                output_list.remove(element)

    return output_list


if __name__ == '__main__':
    listout = [x.decode('utf-8').strip() for x in listout]
    uniq = unique(listout)
    filtered = remove_unnecessary(uniq)

    print("\nFound these USB ports:")
    print(*filtered, sep='\n')
    print("")

    orig_stdout = sys.stdout
    with open("usb.portlist", "w+") as f:
        sys.stdout = f
        print(*filtered, sep='\n')
        sys.stdout = orig_stdout
    
    print("Results were saved to 'usb.portlist'.")

