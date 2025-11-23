# Description

My nixos configuration files.

# Configuration files

## Templates

### Minimal ssh configuration

This is a minimal configuration based on the default to be able to ssh into a proxmox vm.

The associated vm config is:
  - OS: Use CD/DVD disc image file (iso): Choose the NixOS ISO
  - System
    - Graphics card: Virtio-GPU
    - Machine: q35 
    - BIOS: OVMF (UEFI)
    - SCSI controller: VirtIO SCSI single
    - Qemu agent: True
  - Disks: 
    - Bus/Device: Virtio Block
    - Size: e.g. 20GB
    - Cache: No cache / Write back (better performance)
    - Discard: True (best to mantain ssd health)
    - IO Thread: True (best performance)
  - CPU: 
    - 1 socket, 2 cores
    - Type: x86-64-v2-AES / Host
  - Memory: 2048–4096 MB
  - Network:
    - Model: VirtIO (paravirtualized)
    - Bridge: vmbr0

**If getting an access denied error when booting from cd, disable secure boot from boot manager.**

As I used a non graphical installer I had to create the partitions. I include the commands I used.

```shell
sudo -i

lsblk

cfdisk /dev/vda
  gpt
    1G, EFI
    4G, Linux swap
    rest, Linux filesystem
  write, yes
  quit

mkfs.ext4 -L nixos /dev/vda3
mkswap -L swap /dev/vda2
mkfs.fat -F 32 -n boot /dev/vda1

mount /dev/vda3 /mnt
mount --mkdir /dev/vda1 /mnt/boot
swapon /dev/vda2

lsblk

nixos-generate-config --root /mnt
```

I git cloned this repo to get the public key and copied into 

```shell

mkdir -p /home/cacu/nixos/ssh-keys
cd /home/cacu
git clone https://github.com/khakhux/nix-config-server-n150.git
cp nix-config-server-n150/ssh-keys/id_ed25519_nixos.pub nixos/ssh-keys

cp /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix.default
cp nix-config-server-n150/templates/minimal-ssh-configuration.nix /mnt/etc/nixos/configuration.nix
```

***I edited the /mnt/etc/mixos/configuration.nix to create the template file***.

```shell
nixos-install
```

