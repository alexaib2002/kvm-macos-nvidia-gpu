#!/bin/bash
# Get environment variables
source /etc/libvirt/hooks/qemu.d/machine-gpu/pci-passthrough.conf

# Nvidia workaround
if [[ $NVIDIA_BLACKSCREEN_REBOOT = true ]]; then systemctl reboot; exit 0; fi

# Unload VFIO-PCI Kernel Driver
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Reattach GPU to the host
virsh nodedev-reattach pci_0000_26_00_1
virsh nodedev-reattach pci_0000_26_00_0
virsh nodedev-reattach pci_0000_28_00_3

#Load nvidia driver
modprobe drm
modprobe drm_kms_helper
modprobe i2c_nvidia_gpu
modprobe nvidia
modprobe nvidia_modeset
modprobe nvidia_drm
modprobe nvidia_uvm

# Rebind VT consoles
echo 1 > /sys/class/vtconsole/vtcon1/bind

#nvidia-xconfig --query-gpu-info > /dev/null 2>&1
# Re-Bind EFI-Framebuffer
#echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

# Re-Bind systemd isolated CPUs
systemctl set-property --runtime -- user.slice AllowedCPUs=0-11
systemctl set-property --runtime -- system.slice AllowedCPUs=0-11
systemctl set-property --runtime -- init.slice AllowedCPUs=0-11

# Start systemd graphical target
systemctl start graphical.target
