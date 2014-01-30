# Download a kernel from an RPM package
# Variables:
#  - DEVICE (device codename)
#  - KERNEL_RPM (URL to RPM containing kernel0

zImage-$(DEVICE):
	curl $(KERNEL_RPM) | rpm2cpio | cpio -idmv ./boot/zImage
	mv boot/zImage $@
	rm -rd boot
