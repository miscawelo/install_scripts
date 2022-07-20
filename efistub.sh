#!/usr/bin/bash

source /home/miscawelo/scripts/efistub/efistub.conf

# Root partition
root_uuid=$(sudo blkid | grep LUKS | cut -d '"' -f 2)

# Boot partition
boot_partition="$(lsblk -l | grep boot | cut -d ' ' -f 1)"
boot_drive="/dev/"${boot_partition%p*}
boot_part=${boot_partition#*p}

# Swap and hibernation
swap_uuid=$(grep root -A1 /etc/fstab | tail -n 1 |  sed -e 's/.*UUID=//' | cut -d $'\t' -f 1)
swap_offset=$(sudo filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}')
hibernation="resume=UUID="$swap_uuid" resume-offset="$swap_offset

# LUKS options
luks_options="rd.luks.options="$luks_options

sudo rm /tmp/cmd_line &> /dev/null
echo "root=UUID="$root_uuid" rw "$luks_options" "$hibernation" "$kernel_params > /tmp/cmd_line

for linuz in $efi_dir/vmlinuz*; do
    kernel=${linuz#*-}
    echo "Creating unified kernel image for $kernel"
    sudo rm /tmp/$kernel &> /dev/null
    cat $efi_dir/$ucode $efi_dir/booster-$kernel.img > /tmp/$kernel
    objcopy \
        --add-section .osrel="/usr/lib/os-release" --change-section-vma .osrel=0x20000 \
        --add-section .cmdline="/tmp/cmd_line" --change-section-vma .cmdline=0x30000 \
        --add-section .linux="$linuz" --change-section-vma .linux=0x2000000 \
        --add-section .initrd="/tmp/$kernel" --change-section-vma .initrd=0x3000000 \
        "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" "$kernel.efi"
    sudo cp $kernel.efi $efi_dir/EFI/Linux
    sudo rm $kernel.efi &> /dev/null

    entry=$(efibootmgr | grep "($kernel)" | grep -oP "(?<=Boot).*(?=\*)")
    if [[ ! -z $entry ]]; then
        for i in $(echo $entry); do
            sudo efibootmgr -Bb "$i" &> /dev/null
        done
    fi
    sudo efibootmgr --create --disk $boot_drive --part $boot_part --label "$distro ($kernel)" --loader 'EFI\Linux\'$kernel.efi &> /dev/null
done

sudo sbctl sign-all
