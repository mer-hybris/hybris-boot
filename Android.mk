#
# Copyright (C) 2014 David Greaves <david.greaves@jolla.com>
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

HYBRIS_IMG_COMMAND := mkbootimg
HYBRIS_IMG_COMMAND_ARGS := --cmdline 'console=ttySAC2,115200 bootmode=recovery' --base 0x00000000 --pagesize 2048 --kernel_offset 0x40008000 --ramdisk_offset 0x41000000 --second_offset 0x40f00000 --tags_offset 0x40000100 --board '' 

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
BOOT_RAMDISK_FILES := $(shell find $(BOOT_RAMDISK_SRC) -type f)

BB_STATIC := busybox
# BB doesn't explicitly state a dependency on bionic's libm
# State it here for our minimal build
BB_STATIC: libm 

$(LOCAL_BUILT_MODULE): $(INSTALLED_KERNEL_TARGET) $(BOOT_RAMDISK) $(HYBRIS_IMG_COMMAND)
	@echo "Making hybris-boot.img in $(dir $@) using $(INSTALLED_KERNEL_TARGET) $(BOOT_RAMDISK)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) $(HYBRIS_IMG_COMMAND) --kernel $(INSTALLED_KERNEL_TARGET) --ramdisk $(BOOT_RAMDISK) --output $@ $(HYBRIS_IMG_COMMAND_ARGS)

$(BOOT_RAMDISK): $(BOOT_RAMDISK_FILES) $(BB_STATIC)
	@echo "Making initramfs : $@"
	@rm -rf $(BOOT_INTERMEDIATE)/initramfs
	@mkdir -p $(BOOT_INTERMEDIATE)/initramfs
	@cp -a $(BOOT_RAMDISK_SRC)/*  $(BOOT_INTERMEDIATE)/initramfs
	@cp $(BB_STATIC) $(BOOT_INTERMEDIATE)/initramfs/bin/
	@for t in $(BUSYBOX_LINKS); do mkdir -p `dirname $$t`; ln -sf /bin/busybox $(BOOT_INTERMEDIATE)/initramfs$$t; done
	@(cd $(BOOT_INTERMEDIATE)/initramfs && find . | cpio -H newc -o ) | gzip -9 > $@

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
RECOVERY_RAMDISK_FILES := $(shell find $(RECOVERY_RAMDISK_SRC) -type f)

BB_STATIC := $(PRODUCT_OUT)/utilities/busybox
# BB doesn't explicitly state a dependency on bionic's libm
# State it here for our minimal build
BB_STATIC: libm

$(LOCAL_BUILT_MODULE): $(INSTALLED_KERNEL_TARGET) $(RECOVERY_RAMDISK) $(HYBRIS_IMG_COMMAND)
	@echo "Making hybris-recovery.img in $(dir $@) using $(INSTALLED_KERNEL_TARGET) $(RECOVERY_RAMDISK)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) $(HYBRIS_IMG_COMMAND) --kernel $(INSTALLED_KERNEL_TARGET) --ramdisk $(RECOVERY_RAMDISK) --output $@ $(HYBRIS_IMG_COMMAND_ARGS)

$(RECOVERY_RAMDISK): $(RECOVERY_RAMDISK_FILES) $(BB_STATIC)
	@echo "Making initramfs : $@"
	@rm -rf $(RECOVERY_INTERMEDIATE)/initramfs
	@mkdir -p $(RECOVERY_INTERMEDIATE)/initramfs
	@cp -a $(RECOVERY_RAMDISK_SRC)/*  $(RECOVERY_INTERMEDIATE)/initramfs
	@cp $(BB_STATIC) $(RECOVERY_INTERMEDIATE)/initramfs/bin/
	@for t in $(BUSYBOX_LINKS); do mkdir -p `dirname $$t`; ln -sf /bin/busybox $(RECOVERY_INTERMEDIATE)/initramfs$$t; done
	@(cd $(RECOVERY_INTERMEDIATE)/initramfs && find . | cpio -H newc -o ) | gzip -9 > $@

