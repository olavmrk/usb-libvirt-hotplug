usb-libvirt-hotplug
===================

This is a script that can be used to attach and detach USB devices from virtual machines based on udev rules.
This allows matching on any attributes available to udev, for example the USB port the device is plugged into.


Usage
-----

First deploy the `usb-libvirt-hotplug.sh` script on the server that is hosting the virtual machines.
E.g.: `/opt/usb-libvirt-hotplug/usb-libvirt-hotplug.sh`.
Make sure that the script is executable:

```
chmod +x /opt/usb-libvirt-hotplug/usb-libvirt-hotplug.sh
```

Once the script is in place, we can add a udev rule for it.
Create a udev rules-file in `/etc/udev/rules.d`, e.g.: `/etc/udev/rules.d/90-usb-libvirt-hotplug.rules`

This file must contain a udev rule that matches the device insertion and removals.

It will typically look something like:

```
SUBSYSTEM=="usb",DEVPATH=="/devices/pci0000:00/0000:00:1a.0/usb1/1-1/1-1.2",RUN+="/opt/usb-libvirt-hotplug/usb-libvirt-hotplug.sh testvm-01"
```

Here we attach any USB device plugged into the USB port identified by `/devices/pci0000:00/0000:00:1a.0/usb1/1-1/1-1.2` to the VM `testvm-01`.

*Note*:
The script has one mandatory parameter, which contains the libvirt domain that the script should attach the device to.
To list your current domains, run `virsh list --all`.

In order to determine what attributes to use for matching, you can use `udevadm monitor`:

```
$ udevadm monitor --property --udev --subsystem-match=usb/usb_device
```

If you want to match a specific USB port, you will probably want to use the `DEVPATH` attribute.
To match a specific device instead, use the `ID_VENDOR_ID` and `ID_MODEL_ID` attributes.

*Note*:
It may be tempting to use `ATTR{busnum}` and `ATTR{devpath}` to match the USB bus and port number.
However, those attributes are only available when the device is added, and not when the device is removed.
This leads to the device not being properly removed from the VM.

After the udev rule file has been saved, you will probably need to ask udev to reload its configuration files.
E.g.:

```
$ sudo service udev reload
```


Troubleshooting
---------------

This section contains information that may be useful when configuring this script.


### Viewing script logs

The script is configured to send all its output to syslog when it is executed from udev.
Where it is logged depends on the host configuration and OS.
On Debian it defaults to showing up in `/var/log/syslog`.


### Running the script manully

If you want to run the script manually (e.g. for debugging), you need to pass the same environment variables as udev.
First you need to determine the BUSNUM and DEVNUM of your device.
This can be found by using `lsusb`:

```
$ lsusb
Bus 001 Device 037: ID 152d:2338 JMicron Technology Corp. / JMicron USA Technology Corp. JM20337 Hi-Speed USB to SATA & PATA Combo Bridge
[...]
```

Here we see that the bus number is `001` and the device number is `037`.
We can then simulate a device insertion by running:

```
$ ACTION=add SUBSYSTEM=usb DEVTYPE=usb_device BUSNUM=001 DEVNUM=037 /opt/usb-libvirt-hotplug/usb-libvirt-hotplug.sh testvm-01
```

A device removal can be simulated by changing `ACTION` to `remove`:

```
$ ACTION=remove SUBSYSTEM=usb DEVTYPE=usb_device BUSNUM=001 DEVNUM=037 /opt/usb-libvirt-hotplug/usb-libvirt-hotplug.sh testvm-01
```


### Inspecting the current QEMU state

Sometimes it may be useful to check the current QEMU state.
This can be done by using `virsh qemu-monitor-command`:

```
$ virsh qemu-monitor-command testvm-01 --hmp 'info usb'
  Device 0.9, Port 2, Speed 12 Mb/s, Product QEMU USB Hub
```

Here we can see that the only device attached is a virtual USB hub.
Once we have added a device, it will show up:

```
$ virsh qemu-monitor-command testvm-01 --hmp 'info usb'
  Device 0.9, Port 2, Speed 12 Mb/s, Product QEMU USB Hub
  Device 0.12, Port 2.3, Speed 12 Mb/s, Product USB to ATA/ATAPI bridge
```


### Manually detaching USB devices

If you have an error in your udev rules, so that devices have not been automatically removed, you may need to do a manual cleanup of the VM.
This can be done by using `virsh`.
First dump the current configuration of the VM in XML format:

```
$ virsh dumpxml testvm-01
```

The output will contain something like:

```
<domain type='kvm' id='3'>
  <name>testvm-01</name>
  <!-- ... -->
  <devices>
    <!-- ... -->
    <video>
      <model type='cirrus' vram='9216' heads='1'/>
      <alias name='video0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <hostdev mode='subsystem' type='usb' managed='no'>
      <source>
        <address bus='1' device='33'/>
      </source>
      <alias name='hostdev0'/>
    </hostdev>
    <hostdev mode='subsystem' type='usb' managed='no'>
      <source>
        <address bus='1' device='34'/>
      </source>
      <alias name='hostdev1'/>
    </hostdev>
    <hostdev mode='subsystem' type='usb' managed='no'>
      <source>
        <address bus='1' device='35'/>
      </source>
      <alias name='hostdev2'/>
    </hostdev>
    <memballoon model='virtio'>
      <alias name='balloon0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </memballoon>
  </devices>
</domain>
```

Here we see three USB devices attached to the VM.
To remove them run `virsh detach-device testvm-01 /dev/stdin`, and paste `<hostdev>` XML:

```
$ virsh detach-device testvm-01 /dev/stdin
    <hostdev mode='subsystem' type='usb' managed='no'>
      <source>
        <address bus='1' device='35'/>
      </source>
      <alias name='hostdev2'/>
    </hostdev>
```

When libvirt has detached the device, it will print something like:

```
Device detached successfully
```
