# Build initramfs.gz and boot.img
#
# Author: Tom Swindell <t.swindell@rubyx.co.uk>
#
$(warning ********************************************************************************)
$(warning *  You are using the non-android-build approach)
$(warning *  Please don't do this.)
$(warning *  Setup an android build chroot and build your img files there.)
$(warning *  Thank you :D )
$(warning ********************************************************************************)

ifneq ($(MAKECMDGOALS),clean)
DEVICE=$(MAKECMDGOALS)
endif

BOOTLOGO ?= 1
NEVERBOOT ?= 0
ALWAYSDEBUG ?= 0

$(DEVICE): setup-$(DEVICE) boot.img-$(DEVICE)

setup-mako:
	$(eval MKBOOTIMG_PARAMS=--cmdline 'console=ttyHSL0,115200,n8 androidboot.hardware=mako lpj=67677' \
		--base 0x80200000 \
		--ramdisk_offset 0x01600000 \
	)

setup-grouper:
	$(eval DATA_PART=/dev/mmcblk0p9)

setup-tilapia:
	$(eval DATA_PART=/dev/mmcblk0p10)

setup-aries:
	$(eval MKBOOTIMG_PARAMS=--cmdline 'console=null androidboot.hardware=qcom ehci-hcd.park=3' --base 0x00000000 --pagesize 2048 --kernel_offset 0x80208000 --ramdisk_offset 0x82200000 --second_offset 0x81100000 --tags_offset 0x80200100 --board '' )
	$(eval DATA_PART=/dev/mmcblk0p26)
	$(eval BOOTLOGO=0)

zImage-mako:
	$(error Please provide the mako zImage)

zImage-aries:
	$(error Please provide the aries zImage)

zImage-grouper:
	(curl "http://repo.merproject.org/obs/home:/tswindell:/hw:/grouper/latest_armv7hl/armv7hl/kernel-asus-grouper-3.1.10+9.26-1.1.1.armv7hl.rpm" | rpm2cpio | cpio -idmv)
	mv ./boot/zImage zImage-grouper
	rm -rf ./boot ./lib

zImage-tilapia: zImage-grouper
	mv zImage-grouper zImage-tilapia

boot.img-$(DEVICE): zImage-$(DEVICE) initramfs.gz-$(DEVICE)
	mkbootimg --kernel ./zImage-$(DEVICE) --ramdisk ./initramfs.gz-$(DEVICE) $(MKBOOTIMG_PARAMS) --output ./boot.img-$(DEVICE)

initramfs/init: init-script
	sed -e 's %DATA_PART% $(DATA_PART) g' init-script | sed -e 's %BOOTLOGO% $(BOOTLOGO) g' | sed -e 's %NEVERBOOT% $(NEVERBOOT) g' | \
	sed -e 's %ALWAYSDEBUG% $(ALWAYSDEBUG) g' > initramfs/init
	chmod +x initramfs/init

initramfs.gz-$(DEVICE): initramfs/bin/busybox initramfs/init initramfs/bootsplash.gz
	(cd initramfs; rm -rf ./usr/share)
	(cd initramfs; find . | cpio -H newc -o | gzip -9 > ../initramfs.gz-$(DEVICE))

initramfs/bin/busybox:
	(cd initramfs; curl "http://repo.merproject.org/obs/home:/tswindell:/hw:/common/latest_armv7hl/armv7hl/busybox-1.21.0-1.1.2.armv7hl.rpm" | rpm2cpio | cpio -idmv)

clean:
	rm ./initramfs/bin/busybox
	rm ./initramfs/init
	rm ./initramfs.gz-*
	rm ./boot.img-*
	rm ./zImage-*

all:
	$(error Usage: make <device>)

