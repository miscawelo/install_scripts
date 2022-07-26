#!/usr/bin/bash

source /install_scripts/efistub.conf

# Root partition
root_uuid=$(sudo blkid | grep LUKS | cut -d '"' -f 2)

# Boot partition
boot_partition="$(lsblk -l | grep boot | cut -d ' ' -f 1)"
boot_drive="/dev/"${boot_partition%p*}
boot_part=${boot_partition#*p}

# LUKS options
luks_options="rd.luks.options="$luks_options

sudo rm /tmp/cmd_line &> /dev/null
echo "root=UUID="$root_uuid" rw "$luks_options" "$kernel_params > /tmp/cmdline

cat /boot/amd-ucode.img /boot/booster-linux.img > /tmp/linux.img

stub_line=$(objdump -h "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" | tail -2 | head -1)
stub_size=0x$(echo "$stub_line" | awk '{print $3}')
stub_offs=0x$(echo "$stub_line" | awk '{print $4}')
osrel_offs=$((stub_size + stub_offs))
cmdline_offs=$((osrel_offs + $(stat -c%s "/usr/lib/os-release")))
splash_offs=$((cmdline_offs + $(stat -c%s "/tmp/cmdline")))
linux_offs=$((splash_offs + $(stat -c%s "/usr/share/systemd/bootctl/splash-arch.bmp")))
initrd_offs=$((linux_offs + $(stat -c%s "/boot/vmlinuz-linux")))

objcopy \
    --add-section .osrel="/usr/lib/os-release" --change-section-vma .osrel=$(printf 0x%x $osrel_offs) \
    --add-section .cmdline="/tmp/cmdline" --change-section-vma .cmdline=$(printf 0x%x $cmdline_offs) \
    --add-section .splash="/usr/share/systemd/bootctl/splash-arch.bmp" --change-section-vma .splash=$(printf 0x%x $splash_offs) \
    --add-section .linux="/boot/vmlinuz-linux" --change-section-vma .linux=$(printf 0x%x $linux_offs) \
    --add-section .initrd="/tmp/linux.img" --change-section-vma .initrd=$(printf 0x%x $initrd_offs) \
    "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" "linux.efi"

    sudo efibootmgr --create --disk $boot_drive --part $boot_part --label "$distro" --loader 'EFI\Linux\'linux.efi &> /dev/null
