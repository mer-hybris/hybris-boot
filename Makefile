# Build initramfs.gz and boot.img
#
# Author: Tom Swindell <t.swindell@rubyx.co.uk>
#

all: boot.img

boot.img: zImage initramfs.gz
	mkbootimg --kernel ./zImage --ramdisk ./initramfs.gz --output ./boot.img

zImage:
	(curl "http://repo.merproject.org/obs/home:/tswindell:/hw:/grouper/latest_armv7hl/armv7hl/kernel-asus-grouper-3.1.10+9.26-1.10.1.armv7hl.rpm" | rpm2cpio | cpio -idmv)
	mv ./boot/zImage .
	rm -rf ./boot ./lib

initramfs.gz: initramfs/bin/busybox initramfs/init initramfs/bootsplash.gz
	(cd initramfs; rm -rf ./usr/share)
	(cd initramfs; find . | cpio -H newc -o | gzip -9 > ../initramfs.gz)

initramfs/bin/busybox:
	(cd initramfs; curl "http://repo.merproject.org/obs/home:/tswindell:/hw:/grouper/latest_armv7hl/armv7hl/busybox-1.21.0-1.1.1.armv7hl.rpm" | rpm2cpio | cpio -idmv)

clean:
	rm ./initramfs/bin/busybox
	rm ./initramfs.gz
	rm ./boot.img
	rm ./zImage

