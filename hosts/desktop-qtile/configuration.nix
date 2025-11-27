{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      (import ../../modules/common-configuration.nix {
        inherit config lib pkgs;
        interfaceName = "ens18";
        ipAddress = "192.168.1.249";
      })
      ../../modules/proxmox-guest.nix
      ../../modules/desktop-qtile.nix
    ];

  # Enable RDP Access
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "qtile start";

  networking = {
    hostName = "desktop-qtile";
    networkmanager.enable = true;
  };

  ssh.allowedUsers = [ "cacu" ];

  system.stateVersion = "25.05"; # Did you read the comment?
}
