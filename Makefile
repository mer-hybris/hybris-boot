# Build initramfs.gz and boot.img
#
# Author: Tom Swindell <t.swindell@rubyx.co.uk>
#

$(DEVICE): setup-$(DEVICE) boot.img-$(DEVICE)

setup-mako:
	$(eval MKBOOTIMG_PARAMS=--cmdline 'console=ttyHSL0,115200,n8 androidboot.hardware=mako lpj=67677' \
		--base 0x80200000 \
		--ramdisk_offset 0x01600000 \
	)

setup-grouper:

zImage-mako:
	$(error Please provide the mako zImage)

zImage-grouper:
	(curl "http://repo.merproject.org/obs/home:/tswindell:/hw:/grouper/latest_armv7hl/armv7hl/kernel-asus-grouper-3.1.10+9.26-1.10.1.armv7hl.rpm" | rpm2cpio | cpio -idmv)
	mv ./boot/zImage zImage-$(DEVICE)
	rm -rf ./boot ./lib

boot.img-$(DEVICE): zImage-$(DEVICE) initramfs.gz-$(DEVICE)
	mkbootimg --kernel ./zImage-$(DEVICE) --ramdisk ./initramfs.gz-$(DEVICE) $(MKBOOTIMG_PARAMS) --output ./boot.img-$(DEVICE)

initramfs.gz-$(DEVICE): initramfs/bin/busybox initramfs/init initramfs/bootsplash.gz
	(cd initramfs; rm -rf ./usr/share)
	(cd initramfs; find . | cpio -H newc -o | gzip -9 > ../initramfs.gz-$(DEVICE))

initramfs/bin/busybox:
	(cd initramfs; curl "http://repo.merproject.org/obs/home:/tswindell:/hw:/grouper/latest_armv7hl/armv7hl/busybox-1.21.0-1.1.1.armv7hl.rpm" | rpm2cpio | cpio -idmv)

clean:
	rm ./initramfs/bin/busybox
	rm ./initramfs.gz
	rm ./boot.img
	rm ./zImage

all:
	$(error Usage: make DEVICE=device)

