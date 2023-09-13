# macOS/KVM with Nvidia single GPU passthrough
This repo contains a basic guide for doing a single GPU passthrough with an Nvidia card in a macOS KVM installation. Note that recent Nvidia cards (RTX 2000 series and upwards) won't work at all, as Nvidia does not provide any macOS support anymore.

## Requirements
- Modern CPU with SSE4.1 and AVX2 support
- 8GB or more RAM available (by doing a single GPU passthrough, your host will still be using RAM)
- Basic knowledge about GPU passthrough (take a look at the [Arch Wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF))

## Host hardware
- CPU: Ryzen 5 2600 (3.4GHz)
- GPU: Nvidia GTX 1060 6GB
- Memory: 16GBs (Dual channel)

# Installing macOS
You will need to setup a working KVM before attempting any passthrough. 
You should follow the instructions provided in the [OSX-KVM repo](https://github.com/kholia/OSX-KVM#installation) to get your VM up and ready.
Keep in mind that you can use any version of macOS, as recent developments in the OpenCore project have made able to enable support for Nvidia GPUs in recent macOS versions.

## Isolating the GPU
After verifying that everything works as intended, you will be ready to prepare the GPU passthrough:
- Find out in which IOMMU group is your GPU located. Usually, you will find two PCI-e devices, one for the GPU and another one for its audio controller.
```
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```
Example output:
```
IOMMU Group 15:
        26:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP106 [GeForce GTX 1060 6GB] [10de:1c03] (rev a1)
        26:00.1 Audio device [0403]: NVIDIA Corporation GP106 High Definition Audio Controller [10de:10f1] (rev a1)
```

- Now, you should edit the `hooks/pci-passthrough.conf` config file. Following the example provided before, the file should look like this:
```
# PCI Passthrough environment variables
GPU_VGA_DEV=pci_0000_26_00_0 # Comes from 26:00.0, the GP106 video controller
GPU_AUDIO_DEV=pci_0000_26_00_1 # Comes from 26:00.1, the GP106 audio controller
HD_AUDIO_CARD=pci_0000_28_00_3 # This one is my motherboard audio controller. You should be able to get it from the output of the command listed above.

# nvidia reboot workaround
# As framebuffer cannot be reattached, reboot system after shuting down the VM
NVIDIA_BLACKSCREEN_REBOOT=true # This variable works as a workaround, as in recent kernels the system may hang if the gpu is reattached to the host.
```

Remember to add the necessary `<hostdev>` tags to the VM XML (you may want to do that with libvirt or virt-manager) so the devices are actually identifiable by libvirt.

## Booting the VM
The script provided in the `hooks` directory will make the system completly exit `graphical.target`, making it enter `multi-user.target` (ie: text-only). 
It will load the necessary `vfio` modules afterwards and detach the card from the host system, unloading all the involved Linux kernel modules.
The VM should boot without any problem, but you will notice it's not using any GPU hardware acceleration. You will need to install the Nvidia
GPU drivers.

## Patching Nvidia drivers
Thanks to [OpenCore Legacy Patcher](https://dortania.github.io/OpenCore-Legacy-Patcher), you will be able to use your GTX GPU with macOS versions past High Sierra, though you won't
get Metal support (this may be a deal-breaker for some, as Apple has effectively stated that OpenGL is deprecated in macOS). Still, the OS itself is able to run smoothly with almost
every app I've tested (VSCode, Safari, Document Viewer and Chromium).

After patching the system, you will need to reboot the system.

Congratulations! You may now rest and enjoy the benefits of running macOS in a VM while having GPU acceleration.

## Some considerations
- As stated before, Nvidia DOES NOT support Metal, so any app that requires it won't be able to run.
- Use qcow2 disk snapsthots. APFS are unlikely to solve any problem you may found with unsupported hardware (undoing Nvidia driver install, kext mods, etc).
- **If your system boots with a black screen even if you are using the GPU rom**, it's very likely that you have a Dual Link cable. I have to disconnect it every time before booting macOS,
otherwise the system will show a blank screen even though it's working.

## Motivation
As I'm a student at 42 Madrid, and we have to code in C using macOS utils and libraries (for example, the `ar` command in macOS behaves differently compared to the Linux one as it does not flatten
the archive layout), I need a replica of that environment to work at home.

Using a VM will always be preferable for me, as macOS is specially picky with the hardware you are using. That means, the VM hardware layout will never change, no matter which computer runs it,
with the only exception being the passedthrough devices. Still, that's a lot better compared to doing a Hackintosh (as my hardware is exactly the opposite of what macOS expects with x86, Ryzen instead of Intel and Nvidia instead of AMD/Intel).

## Credits
- Everyone involved in [OSX-KVM Project](https://github.com/kholia/OSX-KVM), without their hard work this project wouldn't even be possible.
- The [OpenCore](https://github.com/acidanthera/OpenCorePkg), for providing the best way to build a Hackintosh and [OpenCore Legacy Patcher](https://dortania.github.io/OpenCore-Legacy-Patcher) for enabling unsupported hardware on the recent macOS versions.
