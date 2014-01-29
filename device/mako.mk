MKBOOTIMG_PARAMS += --cmdline 'console=ttyHSL0,115200,n8 androidboot.hardware=mako lpj=67677'
MKBOOTIMG_PARAMS += --base 0x80200000
MKBOOTIMG_PARAMS += --ramdisk_offset 0x01600000

include device/common/kernel-manual.mk
