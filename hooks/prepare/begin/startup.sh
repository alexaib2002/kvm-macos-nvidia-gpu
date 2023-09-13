#!/bin/bash
# Get environment variables
source /etc/libvirt/hooks/qemu.d/machine-gpu/pci-passthrough.conf

# Change runlevel to multi-user, so we can unload GPU drivers
systemctl isolate multi-user.target

# Tell systemd to not use VM CPUs
systemctl set-property --runtime -- user.slice AllowedCPUs=5,11
systemctl set-property --runtime -- system.slice AllowedCPUs=5,11
systemctl set-property --runtime -- init.slice AllowedCPUs=5,11

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind 
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Unbind EFI-Framebuffer
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Avoid a race condition
sleep 3

# Unload all Nvidia drivers
modprobe -r nvidia_drm
modprobe -r nvidia_uvm
modprobe -r nvidia_modeset
modprobe -r drm_kms_helper
modprobe -r nvidia
modprobe -r i2c_nvidia_gpu
modprobe -r drm

# Detach GPU from display driver
virsh nodedev-detach $GPU_VGA_DEV
virsh nodedev-detach $GPU_AUDIO_DEV
virsh nodedev-detach $HD_AUDIO_CARD

# Load VFIO kernel module
modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
