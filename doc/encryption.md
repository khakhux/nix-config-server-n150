# Tasks

- Finish claude message
- Extract encryptedContainers info to text file
- environment.systemPackages defined twice (error)
- pkgs.systemd to install systemd-cryptenroll for FIDO2?


# Description

I have a nixos server which I use as a nas. I would like to have some files encrypted. I want to be able to access them via sftp from windows 11 and linux desktops and from my android phone.

I was thinking in having them in a luks container which is normally unmounted but t be able to mount it on demand so I can access the files unencrypted. Another option would be to have small volumes that I copy encrypted to the client to ne unencrypted there. I would like to use a yubikey that has to be inserted on the machine to unencrypt the files.

What are my options?

As of now I use VeraCrypt and Bitlocker for encrypting files and disks.

I have termux and termius installed in my android phone. I own a couple of yubikeys.

# Open source projects

## Tomb

https://github.com/dyne/tomb/
https://github.com/dyne/tomb/blob/master/doc/FIDO2.md
[Create FIDO device with rpi pico and fidelio](https://github.com/danielinux/fidelio)

# 

## Install 

## Create LUKS container

Use [/scripts/create-luks-container.sh](../scripts/create-luks-container.sh)

For example: `sudo ./create-luks-container.sh -p /datos/doc-admin.img -s 20G`

Commands as reference:
```shell
# Create a file for the container (adjust size as needed, e.g., 10G)
sudo dd if=/dev/zero of=/path/to/your/encrypted-container.img bs=1M count=10240 status=progress

# Format as LUKS
sudo cryptsetup luksFormat /path/to/your/encrypted-container.img

# Open the container
sudo cryptsetup open /path/to/your/encrypted-container.img encrypted-storage

# Create a filesystem (ext4 example)
sudo mkfs.ext4 /dev/mapper/encrypted-storage

# Close it
sudo cryptsetup close encrypted-storage
```

## Usage

Using the standalone script:
```shell
# Make it executable
chmod +x luks-manager.sh

# Mount a container
./luks-manager.sh mount /data/private.img /mnt/private

# List all mounted containers
./luks-manager.sh list

# Unmount
./luks-manager.sh umount /mnt/private

# Get status
./luks-manager.sh status private-encrypted
```

With NixOS configuration:
```shell
# Use the convenience commands
mount-storage
mount-personal

# Or use the generic command
luks-manager mount /data/any-container.img /mnt/anywhere

# Check status of all configured containers
encrypted-status

# Unmount
umount-storage

# Or use systemd (if you enabled the services)
sudo systemctl start encrypted-mount-storage.service
sudo systemctl stop encrypted-mount-storage.service
```

Auto-unmount Behavior

The auto-unmount feature works by:
1. Starting a timer when you mount a container
2. After the specified period of inactivity (e.g., "30min"), the timer triggers
3. The service checks if the container is still mounted
4. If mounted, it unmounts it automatically

To enable/disable auto-unmount for a specific container, just set or remove the autoUmountAfter field in the configuration.

## Configure SFTP Access

```nix
services.openssh = {
  enable = true;
  settings = {
    PasswordAuthentication = false;  # Use key-based auth
  };
};

# Optional: Restrict SFTP users to specific directory
services.openssh.extraConfig = ''
  Match Group sftpusers
    ChrootDirectory /mnt/encrypted
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
'';
```