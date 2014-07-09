hybris-boot
===========

This project enables the building of boot images for Google Android fastboot based devices.

It can be built either in the android build tree as part of the normal kernel/android pre-requisited build or in a Mer SDK as a standalone package

Android Build
-------------

We need to extend subdir_makefiles in build/core/main.mk to include hybris/Android.mk; that then includes any additional Android.mk files in subdirs

Note the default boot.img is created by $(INSTALLED_BOOTIMAGE_TARGET) target in build/core/Makefile and that is used for inspiration.

Add as a normal make/mka target:
    $ mka hybris-boot hybris-recovery

SDK Building
------------

In the SDK you'll need the kernel, module and static busybox packages available

    $ git clone https://github.com/mer-hybris/hybris-boot
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

    $ telnet 192.168.2.15

