#!/bin/bash

#
# usb-libvirt-hotplug.sh
#
# This script can be used to hotplug USB devices to libvirt virtual
# machines from udev rules.
#
# This can be used to attach devices when they are plugged into a
# specific port on the host machine.
#
# See: https://github.com/olavmrk/usb-libvirt-hotplug
#

# Abort script execution on errors
set -e

PROG="$(basename "$0")"

if [ ! -t 1 ]; then
  # stdout is not a tty. Send all output to syslog.
  coproc logger --tag "${PROG}"
  exec >&${COPROC[1]} 2>&1
fi

DOMAIN="$1"
if [ -z "${DOMAIN}" ]; then
  echo "Missing libvirt domain parameter for ${PROG}." >&2
  exit 1
fi


#
# Do some sanity checking of the udev environment variables.
#

if [ -z "${SUBSYSTEM}" ]; then
  echo "Missing udev SUBSYSTEM environment variable." >&2
  exit 1
fi
if [ "${SUBSYSTEM}" != "usb" ]; then
  echo "Invalid udev SUBSYSTEM: ${SUBSYSTEM}" >&2
  echo "You should probably add a SUBSYSTEM=\"USB\" match to your udev rule." >&2
  exit 1
fi

if [ -z "${DEVTYPE}" ]; then
  echo "Missing udev DEVTYPE environment variable." >&2
  exit 1
fi
if [ "${DEVTYPE}" == "usb_interface" ]; then
  # This is normal -- sometimes the udev rule will match
  # usb_interface events as well.
  exit 0
fi
if [ "${DEVTYPE}" != "usb_device" ]; then
  echo "Invalid udev DEVTYPE: ${DEVTYPE}" >&2
  exit 1
fi

if [ -z "${ACTION}" ]; then
  echo "Missing udev ACTION environment variable." >&2
  exit 1
fi
if [ "${ACTION}" == 'add' ]; then
  COMMAND='attach-device'
elif [ "${ACTION}" == 'remove' ]; then
  COMMAND='detach-device'
else
  echo "Invalid udev ACTION: ${ACTION}" >&2
  exit 1
fi

if [ -z "${BUSNUM}" ]; then
  echo "Missing udev BUSNUM environment variable." >&2
  exit 1
fi
if [ -z "${DEVNUM}" ]; then
  echo "Missing udev DEVNUM environment variable." >&2
  exit 1
fi


#
# This is a bit ugly. udev passes us the USB bus number and
# device number with leading zeroes. E.g.:
#   BUSNUM=001 DEVNUM=022
# This causes libvirt to assume that the numbers are octal.
# To work around this, we need to strip the leading zeroes.
# The easiest way is to ask bash to convert the numbers from
# base 10:
#
BUSNUM=$((10#$BUSNUM))
DEVNUM=$((10#$DEVNUM))

#
# Now we have all the information we need to update the VM.
# Run the appropriate virsh-command, and ask it to read the
# update XML from stdin.
#
echo "Running virsh ${COMMAND} ${DOMAIN} for USB bus=${BUSNUM} device=${DEVNUM}:" >&2
virsh "${COMMAND}" "${DOMAIN}" /dev/stdin <<END
<hostdev mode='subsystem' type='usb'>
  <source>
    <address bus='${BUSNUM}' device='${DEVNUM}' />
  </source>
</hostdev>
END
