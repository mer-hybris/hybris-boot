MKBOOTIMG_PARAMS += --cmdline 'console=null androidboot.hardware=qcom ehci-hcd.park=3'
MKBOOTIMG_PARAMS += --base 0x00000000 --pagesize 2048 --kernel_offset 0x80208000
MKBOOTIMG_PARAMS += --ramdisk_offset 0x82200000 --second_offset 0x81100000
MKBOOTIMG_PARAMS += --tags_offset 0x80200100 --board ''

DATA_PART := /dev/mmcblk0p26
BOOTLOGO := 0

include device/common/kernel-manual.mk
