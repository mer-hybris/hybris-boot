# Busybox provider

BUSYBOX_RPM=http://repo.merproject.org/obs/home:/tswindell:/hw:/common/latest_armv7hl/armv7hl/busybox-1.21.0-1.1.2.armv7hl.rpm

initramfs-%/bin/busybox: initramfs-%
	cd $< && curl $(BUSYBOX_RPM) | rpm2cpio | cpio -idmv ./bin/busybox
