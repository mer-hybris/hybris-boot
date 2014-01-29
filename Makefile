# Build initramfs.gz and boot.img
#
# Author: Tom Swindell <t.swindell@rubyx.co.uk>
#

include device/common/defaults.mk
include device/common/busybox.mk

ifneq ($(MAKECMDGOALS),clean)
  DEVICE := $(MAKECMDGOALS)

  ifneq ($(DEVICE),)
    # Device-specific configuration
    include device/$(DEVICE).mk
  endif
endif

MKBOOTIMG ?= mkbootimg

help:
	@echo ""
	@echo "Usage: make <device>"
	@echo ""
	@echo "Supported devices:"
	@echo ""
	@echo "    $(patsubst device/%.mk,%,$(wildcard device/*.mk))"
	@echo ""

$(DEVICE): boot.img-$(DEVICE)

boot.img-%: zImage-% initramfs.gz-%
	$(MKBOOTIMG) --kernel $< \
	    --ramdisk $(word 2,$^) \
	    $(MKBOOTIMG_PARAMS) \
	    --output $@

initramfs-%:
	mkdir $@
	cp -rpv initramfs/* $@

initramfs-%/init: init-script device/%.mk initramfs-%
	sed -e 's %DATA_PART% $(DATA_PART) g' \
	    -e 's %BOOTLOGO% $(BOOTLOGO) g' \
	    -e 's %NEVERBOOT% $(NEVERBOOT) g' \
	    -e 's %ALWAYSDEBUG% $(ALWAYSDEBUG) g' \
	    $< >$@
	chmod +x $@

initramfs.gz-%: initramfs-% initramfs-%/bin/busybox initramfs-%/init
	(cd $<; find . | cpio -H newc -o | gzip -9) >$@

clean:
	rm -rf initramfs-*
	rm -f zImage-* initramfs.gz-*

distclean: clean
	rm -f boot.img-*

.PHONY: help clean distclean
.PRECIOUS: initramfs-% initramfs-%/bin/busybox initramfs-%/init
