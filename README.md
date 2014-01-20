hybris-boot
===========

This project enables the building of boot images for Google Android fastboot based devices, currently the Makefile is hard coded to download armv7hl kernel zImage and busybox-static binaries for Google Nexus 7 2012 devices from Mer OBS. In order to boot other devices it may be necessary to supply your own kernel and busybox binary URLs.

Building
--------

    $ git clone https://github.com/tswindell/hybris-boot
    $ cd hybris-boot
    $ make <device>

Operating System Bootstrap
---------------------------

The initramfs boots into a Mer derived OS installation by loading first the default Android /data partition and then bind mounting a root filesystem under /data/media/0/.stowaways/sffe. This behaviour is easily modified by editing the ./initramfs/init shell script.

Initial RAM FS Debug Console
----------------------------

With your device booted to fastboot, boot the boot.img in debug mode:

    $ sudo fastboot boot boot.img -c bootmode=debug

Wait for your host computer to pick up DHCP lease from usb network device:

    $ telnet 192.168.2.1

