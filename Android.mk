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
HYBRIS_B_NEVERBOOT :=
HYBRIS_B_ALWAYSDEBUG :=
# RECOVERY
HYBRIS_R_NEVERBOOT :=
HYBRIS_R_ALWAYSDEBUG := q

## All manual "config" should be done above this line

# Force deferred assignment

# This is the best approach I can find to determine the mapping for /data
# It's based on how kernel finds prebuilts in kernel.mk and the
# observation that all the fstabs mentioned in all the .mk files live
# in PRODUCT_COPY_FILES which seems not to have a target which
# installs it in the hybris minimal set of repos.
# First find one/more fstabs (we check the _dest in case some sick hw
# developer puppy decides to use a _src which is not called *fstab* :) )
# and then use the _src since _dest is not installed.
HYBRIS_FSTAB :=	$(strip $(foreach cf,$(PRODUCT_COPY_FILES), \
	  $(eval _src := $(call word-colon,1,$(cf))) \
          $(eval _dest := $(call word-colon,2,$(cf))) \
          $(if $(findstring fstab,$(_dest)), \
            $(_src))))

ifeq (,HYBRIS_FSTAB)
   $(error ********************* No fstab found for this device)
endif
# Now we have a number of fstab files - hopefully one has a /data in it
$(warning ********************* fstabs found for this device is/are $(HYBRIS_FSTAB))
HYBRIS_DATA_PART := $(strip $(shell cat $(HYBRIS_FSTAB) | grep /data | cut -f1 -d" "))
$(warning ********************* /data should live on $(HYBRIS_DATA_PART))

## FIXME - count the number of words in HYBRIS_DATA_PART and bitch if >1

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
LOCAL_MODULE_PATH := $(PRODUCT_OUT)/hybris

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
	@sed -e 's %DATA_PART% $(HYBRIS_DATA_PART) g' $(BOOT_RAMDISK_INIT_SRC) | \
	  sed -e 's %BOOTLOGO% $(HYBRIS_BOOTLOGO) g' | \
	  sed -e 's %NEVERBOOT% $(HYBRIS_B_NEVERBOOT) g' | \
	  sed -e 's %ALWAYSDEBUG% $(HYBRIS_B_ALWAYSDEBUG) g' > $@
	@chmod +x $@

################################################################

include $(CLEAR_VARS)
LOCAL_MODULE:= hybris-recovery
LOCAL_MODULE_CLASS := ROOT
LOCAL_MODULE_SUFFIX := .img
LOCAL_MODULE_PATH := $(PRODUCT_OUT)/hybris

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
	@sed -e 's %DATA_PART% $(HYBRIS_DATA_PART) g' $(RECOVERY_RAMDISK_INIT_SRC) | \
	  sed -e 's %BOOTLOGO% $(HYBRIS_BOOTLOGO) g' | \
	  sed -e 's %NEVERBOOT% $(HYBRIS_R_NEVERBOOT) g' | \
	  sed -e 's %ALWAYSDEBUG% $(HYBRIS_R_ALWAYSDEBUG) g' > $@
	@chmod +x $@
