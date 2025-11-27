# Description

My nixos configuration files.

# Config files layout

```pgsql
nixos/
├── flake.nix
├── users.nix (main username config)
├── ssh-keys/ (public keys for ssh clients)
├── modules/
    └── common-configuration.nix
    └── common-home.nix
    └── hardened-ssh.nix
    └── ...
└── hosts/
    └── proxmox-desktop/
        ├── configuration.nix
        └── home.nix
        └── hardware-configuration.nix
```

# Installation

## Proxmox sample vm config

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

## Download iso

Download ISO (graphical or minimal): https://nixos.org/download.html

In Proxmox Web UI:
- Go to local > ISO Images
- Upload the .iso

## Create partitions and Install NixOS

    Start the VM and open the console

    Log in as root (no password)

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

## Clone repo and create machine specific files

Clone repo

```shell
cd repo
mkdir $HOSTNAME
cp /etc/nixos/hardware-configuration.nix $HOSTNAME
cp templates/host/*.nix $HOSTNAME
```

- Change configuration.nix (hostname, interfaceName, ipaddress, add modules, ...).
- Change home.nix

add host to flake.nix
```shell
{
  ...
in {
      nixosConfigurations = {
        server-docker-01 = mkHost "server-docker-01";
        new-server = mkHost "new-server";
      };
    };
}
```

```shell
nixos-install --flake ./nixos#hostname
```

## Create 2fa qr code

`google-authenticator`

## The machine config files are already in the repo

If the machine config files are already in the repo the repo cab be cloned and do the nixos-install or use `nixos-install --flake github:yourname/nixos-config#proxmox-desktop` command.



# How I created the config files in the repo

## Templates

### Minimal ssh configuration

This is a minimal configuration based on the default to be able to ssh into a proxmox vm.


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

# Docker iot nixos server

- ssh hardened
- docker and docker compose installation
- Create docker network argea_iot
- 2FA
- samba
- 4_playbook-samba.yaml
- jq
- yt-dlp (docker / nixos module / flatpinch)
- raid 1 disks array
- preparar-backups.yml
- delay docker start to disks mounting if data is stored there (instalacion-host-domotica-ansible.md#Retrasar inicio servicio docker)
  - duplicati
  - jellyfin
  - transmission
  - music-assistant-server (/usbhdd/Music/Temas)
  - homeassistant (/usbhdd/Music/Temas/:/mnt/music)
  - influxdb (/backups/influxdb)
- [#190 advanced security](https://github.com/khakhux/domotica/issues/190)
- clone or copy /docker_data
- copy secrets or use sops

No:
- mosquitto (lo instalo como addon de HASSOS)
- install HACS
- 