#
# Copyright (C) 2014 Jolla Oy
# Contact: <david.greaves@jolla.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

LOCAL_PATH:= $(call my-dir)
HYBRIS_PATH:=$(LOCAL_PATH)

# We use the commandline and kernel configuration varables from
# build/core/Makefile to be consistent. Support for boot/recovery
# image specific kernel COMMANDLINE vars is provided but whether it
# works or not is down to your bootloader.

HYBRIS_BOOTIMG_COMMANDLINE :=
HYBRIS_RECOVERYIMG_COMMANDLINE := bootmode=debug
HYBRIS_BOOTLOGO :=
# BOOT
HYBRIS_B_DEFAULT_OS := sailfishos
HYBRIS_B_ALWAYSDEBUG :=
# RECOVERY
HYBRIS_R_DEFAULT_OS := sailfishos
HYBRIS_R_ALWAYSDEBUG := 1

## All manual "config" should be done above this line

# Force deferred assignment

HYBRIS_FIXUP_MOUNTS := $(LOCAL_PATH)/fixup-mountpoints


# Find any fstab files for required partition information.
# in AOSP we could use TARGET_VENDOR
# TARGET_VENDOR := $(shell echo $(PRODUCT_MANUFACTURER) | tr '[:upper:]' '[:lower:]')
# but Cyanogenmod seems to use device/*/$(TARGET_DEVICE) in config.mk so we will too.
HYBRIS_FSTABS := $(shell find device/*/$(TARGET_DEVICE) -name *fstab* | grep -v goldfish)

# Get the unique /dev field(s) from the line(s) containing the fs mount point
# Note the perl one-liner uses double-$ as per Makefile syntax
HYBRIS_BOOT_PART := $(shell /usr/bin/perl -w -e '$$fs=shift; while (<>) { next unless /^$$fs\s|\s$$fs\s/;for (split) {next unless m(^/dev); print "$$_\n"; }}' /boot $(HYBRIS_FSTABS) | sort -u)
HYBRIS_DATA_PART := $(shell /usr/bin/perl -w -e '$$fs=shift; while (<>) { next unless /^$$fs\s|\s$$fs\s/;for (split) {next unless m(^/dev); print "$$_\n"; }}' /data $(HYBRIS_FSTABS) | sort -u)

$(warning ********************* /boot appears to live on $(HYBRIS_BOOT_PART))
$(warning ********************* /data appears to live on $(HYBRIS_DATA_PART))

ifneq ($(words $(HYBRIS_BOOT_PART))$(words $(HYBRIS_DATA_PART)),11)
$(error There should be a one and only one device entry for HYBRIS_BOOT_PART and HYBRIS_DATA_PART)
endif

# Command used to make the image
MKBOOTIMG := mkbootimg
BB_STATIC := $(PRODUCT_OUT)/utilities/busybox

HYBRIS_BOOTIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
	--kernel $(INSTALLED_KERNEL_TARGET)

ifdef BOARD_KERNEL_BASE
  HYBRIS_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif

ifdef BOARD_KERNEL_PAGESIZE
  HYBRIS_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

# Specify the BOOT/RECOVERY vars here as they're not impacted by
# CLEAR_VARS and it makes it easier to keep them consistent.

HYBRIS_RECOVERYIMAGE_ARGS := $(HYBRIS_BOOTIMAGE_ARGS)

# Strip lead/trail " from broken BOARD_KERNEL_CMDLINEs :(
HYBRIS_BOARD_KERNEL_CMDLINE := $(shell echo '$(BOARD_KERNEL_CMDLINE)' | sed -e 's/^"//' -e 's/"$$//')

ifneq "" "$(strip $(HYBRIS_BOARD_KERNEL_CMDLINE) $(HYBRIS_BOOTIMG_COMMANDLINE))"
  HYBRIS_BOOTIMAGE_ARGS += --cmdline "$(strip $(HYBRIS_BOARD_KERNEL_CMDLINE) $(HYBRIS_BOOTIMG_COMMANDLINE))"
endif

ifneq "" "$(strip $(HYBRIS_BOARD_KERNEL_CMDLINE) $(HYBRIS_RECOVERYIMG_COMMANDLINE))"
  HYBRIS_RECOVERYIMAGE_ARGS += --cmdline "$(strip $(HYBRIS_BOARD_KERNEL_CMDLINE) $(HYBRIS_RECOVERYIMG_COMMANDLINE))"
endif


include $(CLEAR_VARS)
LOCAL_MODULE:= hybris-boot
# Here we'd normally include $(BUILD_SHARED_LIBRARY) or something
# but nothing seems suitable for making an img like this
LOCAL_MODULE_CLASS := ROOT
LOCAL_MODULE_SUFFIX := .img
LOCAL_MODULE_PATH := $(PRODUCT_OUT)

include $(BUILD_SYSTEM)/base_rules.mk
BOOT_INTERMEDIATE := $(call intermediates-dir-for,ROOT,$(LOCAL_MODULE),)

BOOT_RAMDISK := $(BOOT_INTERMEDIATE)/boot-initramfs.gz
BOOT_RAMDISK_SRC := $(LOCAL_PATH)/initramfs
BOOT_RAMDISK_INIT_SRC := $(LOCAL_PATH)/init-script
BOOT_RAMDISK_INIT := $(BOOT_INTERMEDIATE)/init
BOOT_RAMDISK_FILES := $(shell find $(BOOT_RAMDISK_SRC) -type f) $(BOOT_RAMDISK_INIT)

$(LOCAL_BUILT_MODULE): $(INSTALLED_KERNEL_TARGET) $(BOOT_RAMDISK) $(MKBOOTIMG)
	@echo "Making hybris-boot.img in $(dir $@) using $(INSTALLED_KERNEL_TARGET) $(BOOT_RAMDISK)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide)$(MKBOOTIMG) --ramdisk $(BOOT_RAMDISK) $(HYBRIS_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@

$(BOOT_RAMDISK): $(BOOT_RAMDISK_FILES) $(BB_STATIC)
	@echo "Making initramfs : $@"
	@rm -rf $(BOOT_INTERMEDIATE)/initramfs
	@mkdir -p $(BOOT_INTERMEDIATE)/initramfs
	@cp -a $(BOOT_RAMDISK_SRC)/*  $(BOOT_INTERMEDIATE)/initramfs
# Deliberately do an mv to force rebuild of init every time since it's
# really hard to depend on things which may affect init.
	@mv $(BOOT_RAMDISK_INIT) $(BOOT_INTERMEDIATE)/initramfs/init
	@cp $(BB_STATIC) $(BOOT_INTERMEDIATE)/initramfs/bin/
	@(cd $(BOOT_INTERMEDIATE)/initramfs && find . | cpio -H newc -o ) | gzip -9 > $@

$(BOOT_RAMDISK_INIT): $(BOOT_RAMDISK_INIT_SRC) $(ALL_PREBUILT)
	@mkdir -p $(dir $@)
	@sed -e 's %DATA_PART% $(HYBRIS_DATA_PART) g' \
	  -e 's %BOOTLOGO% $(HYBRIS_BOOTLOGO) g' \
	  -e 's %DEFAULT_OS% $(HYBRIS_B_DEFAULT_OS) g' \
	  -e 's %ALWAYSDEBUG% $(HYBRIS_B_ALWAYSDEBUG) g' $(BOOT_RAMDISK_INIT_SRC) > $@
	$(HYBRIS_FIXUP_MOUNTS) "$(TARGET_DEVICE)" "$@"
	@chmod +x $@

################################################################

include $(CLEAR_VARS)
LOCAL_MODULE:= hybris-recovery
LOCAL_MODULE_CLASS := ROOT
LOCAL_MODULE_SUFFIX := .img
LOCAL_MODULE_PATH := $(PRODUCT_OUT)

include $(BUILD_SYSTEM)/base_rules.mk
RECOVERY_INTERMEDIATE := $(call intermediates-dir-for,ROOT,$(LOCAL_MODULE),)

RECOVERY_RAMDISK := $(RECOVERY_INTERMEDIATE)/recovery-initramfs.gz
RECOVERY_RAMDISK_SRC := $(LOCAL_PATH)/initramfs
RECOVERY_RAMDISK_INIT_SRC := $(LOCAL_PATH)/init-script
RECOVERY_RAMDISK_INIT := $(RECOVERY_INTERMEDIATE)/init
RECOVERY_RAMDISK_FILES := $(shell find $(RECOVERY_RAMDISK_SRC) -type f) $(RECOVERY_RAMDISK_INIT)

$(LOCAL_BUILT_MODULE): $(INSTALLED_KERNEL_TARGET) $(RECOVERY_RAMDISK) $(MKBOOTIMG)
	@echo "Making hybris-recovery.img in $(dir $@) using $(INSTALLED_KERNEL_TARGET) $(RECOVERY_RAMDISK)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide)$(MKBOOTIMG) --ramdisk $(RECOVERY_RAMDISK) $(HYBRIS_RECOVERYIMAGE_ARGS) $(BOARD_MKRECOVERYIMG_ARGS) --output $@

$(RECOVERY_RAMDISK): $(RECOVERY_RAMDISK_FILES) $(BB_STATIC)
	@echo "Making initramfs : $@"
	@rm -rf $(RECOVERY_INTERMEDIATE)/initramfs
	@mkdir -p $(RECOVERY_INTERMEDIATE)/initramfs
	@cp -a $(RECOVERY_RAMDISK_SRC)/*  $(RECOVERY_INTERMEDIATE)/initramfs
	@mv $(RECOVERY_RAMDISK_INIT) $(RECOVERY_INTERMEDIATE)/initramfs/init
	@cp $(BB_STATIC) $(RECOVERY_INTERMEDIATE)/initramfs/bin/
	@(cd $(RECOVERY_INTERMEDIATE)/initramfs && find . | cpio -H newc -o ) | gzip -9 > $@

$(RECOVERY_RAMDISK_INIT): $(RECOVERY_RAMDISK_INIT_SRC) $(ALL_PREBUILT)
	@mkdir -p $(dir $@)
	@sed -e 's %DATA_PART% $(HYBRIS_DATA_PART) g' \
	  -e 's %BOOTLOGO% $(HYBRIS_BOOTLOGO) g' \
	  -e 's %DEFAULT_OS% $(HYBRIS_R_DEFAULT_OS) g' \
	  -e 's %ALWAYSDEBUG% $(HYBRIS_R_ALWAYSDEBUG) g' $(RECOVERY_RAMDISK_INIT_SRC) > $@
	$(HYBRIS_FIXUP_MOUNTS) "$(TARGET_DEVICE)" "$@"
	@chmod +x $@


################################################################
include $(CLEAR_VARS)
LOCAL_MODULE := hybris-updater-script
LOCAL_MODULE_CLASS := ROOT
LOCAL_MODULE_PATH := $(PRODUCT_OUT)

include $(BUILD_SYSTEM)/base_rules.mk
UPDATER_INTERMEDIATE := $(call intermediates-dir-for,ROOT,$(LOCAL_MODULE),)

UPDATER_SCRIPT_SRC := $(LOCAL_PATH)/updater-script

$(LOCAL_BUILT_MODULE): $(UPDATER_SCRIPT_SRC)
	@echo "Installing updater .zip script resources."
	mkdir -p $(dir $@)
	rm -rf $@
	@sed -e 's %DEVICE% $(TARGET_DEVICE) g' \
             -e 's %BOOT_PART% $(HYBRIS_BOOT_PART) g' \
             -e 's %DATA_PART% $(HYBRIS_DATA_PART) g' \
	      $(UPDATER_SCRIPT_SRC) > $@

HYBRIS_UPDATER_SCRIPT := $(LOCAL_BUILD_MODULE)

#---------------------------------------------------------------
include $(CLEAR_VARS)
LOCAL_MODULE := hybris-updater-unpack
LOCAL_MODULE_CLASS := ROOT
LOCAL_MODULE_SUFFIX := .sh
LOCAL_MODULE_PATH := $(PRODUCT_OUT)

include $(BUILD_SYSTEM)/base_rules.mk
UPDATER_INTERMEDIATE := $(call intermediates-dir-for,ROOT,$(LOCAL_MODULE),)

UPDATER_UNPACK_SRC := $(LOCAL_PATH)/updater-unpack.sh

$(LOCAL_BUILT_MODULE): $(UPDATER_UNPACK_SRC)
	@echo "Installing updater .zip script resources."
	mkdir -p $(dir $@)
	rm -rf $@
	@sed -e 's %DEVICE% $(TARGET_DEVICET) g' \
	     $(UPDATER_UNPACK_SRC) > $@

HYBRIS_UPDATER_UNPACK := $(LOCAL_BUILD_MODULE)


.PHONY: hybris-hal
hybris-hal: hybris-updater-unpack hybris-updater-script hybris-recovery hybris-boot linker init libc adb adbd libEGL libGLESv2 bootimage servicemanager logcat updater

