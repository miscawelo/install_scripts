#!/usr/bin/bash

stub_line=$(objdump -h "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" | tail -2 | head -1)
stub_size=0x$(echo "$stub_line" | awk '{print $3}')
stub_offs=0x$(echo "$stub_line" | awk '{print $4}')
osrel_offs=$((stub_size + stub_offs))
cmdline_offs=$((osrel_offs + $(stat -c%s "/usr/lib/os-release")))
splash_offs=$((cmdline_offs + $(stat -c%s "/etc/kernel/cmdline")))
linux_offs=$((splash_offs + $(stat -c%s "/usr/share/systemd/bootctl/splash-arch.bmp")))
initrd_offs=$((linux_offs + $(stat -c%s "vmlinuz-file")))
objcopy \
    --add-section .osrel="/usr/lib/os-release" --change-section-vma .osrel=$(printf 0x%x $osrel_offs) \
    --add-section .cmdline="/install_scripts/cmdline" \
    --change-section-vma .cmdline=$(printf 0x%x $cmdline_offs) \
    --add-section .splash="/usr/share/systemd/bootctl/splash-arch.bmp" \
    --change-section-vma .splash=$(printf 0x%x $splash_offs) \
    --add-section .linux="vmlinuz-file" \
    --change-section-vma .linux=$(printf 0x%x $linux_offs) \
    --add-section .initrd="/tmp/linux.img" \
    --change-section-vma .initrd=$(printf 0x%x $initrd_offs) \
    "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" "linux.efi"
