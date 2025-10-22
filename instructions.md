# Refs

https://nixos.org/learn/

https://nixos.org/manual/nixos/stable/#sec-installation

# Install with flakes

Install Nix with Flake Support
On a temporary system (e.g., NixOS Live USB), enable flakes:
```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

Create Directory Structure
On your local dev machine (or inside the Live USB environment):
```shell
git init nixos-config
cd nixos-config
mkdir -p hosts modules
```

## Files layout

```pgsql
nixos-config/
├── flake.nix
├── flake.lock               # Auto-generated after first build
├── hosts/
│   └── minipc.nix
├── modules/
│   └── docker.nix
│   ├── common-users.nix
│   └── networking.nix
├── secrets/
│   └── secrets.yaml (sops)
├── hardware/
│   └── minipc-hardware.nix
```

flake.nix
```nix
{
  description = "NixOS Flake Config for my mini PC server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: {
    nixosConfigurations.minipc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/minipc.nix
        ./hardware-configuration.nix
        home-manager.nixosModules.home-manager
      ];
    };
  };
}
```

modules/common-users.nix
```nix
{ config, pkgs, ... }:

{
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
```

modules/static-network.nix
```nix
{ interfaceName, ipAddress, gateway ? "192.168.1.1", nameservers ? [ "1.1.1.1" "8.8.8.8" ] }:

{ config, ... }:

{
  networking.interfaces = {
    # Use the dynamic key syntax for interface name
    "${interfaceName}" = {
      useDHCP = false;
      ipv4.addresses = [{
        address = ipAddress;
        prefixLength = 24;
      }];
    };
  };

  networking.defaultGateway = gateway;
  networking.nameservers = nameservers;
}
```

How to Find Your Interface Name: ip link

hosts/minipc.nix
```nix
{ config, pkgs, ... }:

let
  staticNetwork = import ../modules/static-network.nix {
    interfaceName = "enp3s0";
    ipAddress = "192.168.1.100";
  };
in
{
  imports = [
    staticNetwork
    ../modules/common-server.nix
  ];

  networking.hostName = "minipc";
}
```

hosts/minipc.nix (si no funciona modules/static-network.nix)
```nix
{ config, pkgs, ... }:

{
  imports = [
    ../modules/docker.nix
    ../modules/common-users.nix
    ../modules/networking.nix
    ../modules/home/alice.nix 
  ];

  networking.hostName = "minipc";
  
  networking.interfaces.enp3s0 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.1.100";
      prefixLength = 24; # equivalent to subnet mask 255.255.255.0
    }];
  };

  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  users.users.alice = {
    isNormalUser = true;
    home = "/home/alice";
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..." # your SSH key here
    ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.alice = import ../modules/home/alice.nix;

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

modules/docker.nix
```nix
{ config, pkgs, ... }:

{
  virtualisation.docker.enable = true;
  users.groups.docker = { };
}
```

hardware-configuration.nix
```shell
nixos-generate-config --root /mnt
cp hardware-configuration.nix nixos-config
```
```nix
  imports = [
    ./hardware-configuration.nix
  ];
```

modules/home/alice.nix
```nix
{ config, pkgs, ... }:

{
  home.username = "alice";
  home.homeDirectory = "/home/alice";

  programs.zsh.enable = true;
  programs.git = {
    enable = true;
    userName = "Alice Nix";
    userEmail = "alice@example.com";
  };

  #home.packages = with pkgs; [
  #  neofetch # system info tool
  #  htop
  #  bat # modern cat clone with syntax highlighting, line numbers, and Git integration
  #  ripgrep # A blazing-fast alternative to grep
  #  fd # A simpler, faster alternative to find
  #];

  home.stateVersion = "24.05";  # Keep this in sync with system version
}
```

## Build & Install

```shell
sudo nixos-install --flake /mnt/etc/nixos#minipc
```

After boot:
```shell
sudo nixos-rebuild switch --flake /etc/nixos#minipc
```

Generate NixOS Config ???
Hace falta si uso flakes?
```shell
nixos-generate-config --root /mnt
```

## SOPS for Secrets

### Install sops-nix

Add this to your flake.nix:
```nix
{
  description = "My NixOS multi-host config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, flake-utils, sops-nix, ... }:
    {
      nixosConfigurations = {
        minipc = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/minipc.nix
            ./hardware/minipc-hardware.nix
            sops-nix.nixosModules.sops
          ];
        };
        laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/laptop.nix
            ./hardware/laptop-hardware.nix
            sops-nix.nixosModules.sops
          ];
        };
      };
    };
}
```

### Generate an Age key 

(gpg can also be used although age is simpler)

```shell
age-keygen -o age.key
```

Add the public part (public key: ...) to your repo or secrets.yaml file.

Save age.key securely on your machine (or the target server) at /etc/age.key or similar.

### Create a secrets/ folder and a file like secrets.yaml:

```yaml
user-password-hash: ENC[AGE...]
ssh-private-key: ENC[AGE...]
```

Use SOPS to edit it:
```shell
sops --encrypt --age <public-age-key> > secrets/secrets.yaml
```
Or edit interactively:
```shell
sops secrets/secrets.yaml
```

### Reference Secrets in configuration.nix

In hosts/minipc.nix
```nix
{ config, pkgs, ... }:

{
  imports = [
    ../modules/docker.nix
  ];

  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.age.keyFile = "/etc/age.key";  # This must exist on the target system

  sops.secrets.user-password-hash = {};
  sops.secrets.ssh-private-key = {
    owner = "youruser";
    path = "/home/youruser/.ssh/id_rsa";
    mode = "0600";
  };

  users.users.youruser = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    hashedPasswordFile = config.sops.secrets.user-password-hash.path;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3Nz..."  # public key
    ];
  };

  services.openssh.enable = true;

  # Make sure home dir exists
  systemd.tmpfiles.rules = [
    "d /home/youruser/.ssh 0700 youruser users -"
  ];
}
```

### Add to git

```shell
git add secrets/secrets.yaml
```

# Installation steps

## Download ISO

Download Minimal ISO image from [nisox](https://nixos.org/download/#nixos-iso)

[Creating bootable USB flash drive from a Terminal on Linux](https://nixos.org/manual/nixos/stable/#sec-booting-from-usb-linux)

lsblk or fdisk -l

```shell
sudo umount /dev/sdX*
sudo dd bs=4M conv=fsync oflag=direct status=progress if=<path-to-image> of=/dev/sdX
```

## Building a live iso

https://nixos.org/manual/nixos/stable/#sec-building-image

## Boot into NixOS Live Environment

## Create and mount partitions

Partition and Format Disk

Assume your disk is /dev/sda (verify with lsblk or fdisk -l).

```shell
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart root ext4 512MB -8GB
parted /dev/sda -- mkpart swap linux-swap -8GB 100%
parted /dev/sda -- mkpart ESP fat32 1MB 512MB
parted /dev/sda -- set 3 esp on

mkfs.ext4 -L nixos /dev/sda1
mkswap -L swap /dev/sda2 
mkfs.fat -F 32 -n boot /dev/sda3

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot

swapon /dev/sda2
```

## Installation

```shell
nixos-generate-config --flake --root /mnt
```

Clone git repo

```shell
nixos-install --flake 'path/to/flake.nix#nixos'

nixos-enter --root /mnt -c 'passwd cacu'

reboot
```

# Multiple hosts setup

```bash
nixos-config/
├── flake.nix
├── flake.lock
├── hosts/
│   ├── minipc.nix
│   ├── laptop.nix
│   └── server.nix
├── modules/
│   ├── docker.nix
│   ├── common-users.nix
│   └── networking.nix
├── secrets/
│   └── secrets.yaml (sops)
├── hardware/
│   └── minipc-hardware.nix
```

flake.nix
```nix
{
  description = "My NixOS multi-host config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, flake-utils, sops-nix, ... }:
    {
      nixosConfigurations = {
        minipc = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/minipc.nix
            ./hardware/minipc-hardware.nix
            sops-nix.nixosModules.sops
          ];
        };
        laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/laptop.nix
            ./hardware/laptop-hardware.nix
            sops-nix.nixosModules.sops
          ];
        };
      };
    };
}
```

modules/common-users.nix
```nix
{ config, pkgs, ... }:

{
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
```

hosts/minipc.nix
```nix
{ config, pkgs, ... }:

{
  imports = [
    ../modules/common-users.nix
    ../modules/docker.nix
    ../modules/networking.nix
  ];

  networking.hostName = "minipc";

  services.openssh.enable = true;

  swapDevices = [
    { device = "/swapfile"; size = 8192; }
  ];
}
```


# Use yubikey to generate ssh keys

```shell
ssh-keygen -t ed25519-sk -C "your@name"
```

This creates:
~/.ssh/id_ed25519_sk (private key, just a pointer)
~/.ssh/id_ed25519_sk.pub

Add the .pub key to your server.
