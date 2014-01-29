# Manually let the user provide a kernel
# Variables:
#  - DEVICE (device codename)

zImage-$(DEVICE):
	$(error "Please provide $@ manually (or modify device/$(DEVICE).mk)")
