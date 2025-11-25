{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      (import ../../modules/common-configuration.nix {
        inherit config lib pkgs;
        interfaceName = "ens18";
        ipAddress = "192.168.1.248";
      })
      ../../modules/proxmox-guest.nix
    ];

  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
  };

  ssh.allowedUsers = [ "cacu" ];

  system.stateVersion = "25.05"; # Did you read the comment?
}
