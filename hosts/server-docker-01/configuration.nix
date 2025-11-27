{ config, lib, pkgs, ... }:

let
  ports = import ../../ports.nix;
in

{
  imports =
    [
      ./hardware-configuration.nix
      (import ../../modules/common-configuration.nix {
        inherit config lib pkgs;
        interfaceName = "ens18";
        ipAddress = "192.168.1.248";
        extraGroups = "docker";
      })
      ../../modules/docker.nix
      ../../modules/proxmox-guest.nix
    ];

  networking = {
    hostName = "server-docker-01";
    networkmanager.enable = true;
    firewall.enable = true;
    firewall.allowedTCPPorts = [ ports.SSH ports.FRIGATE ];
  };

  ssh.allowedUsers = [ "cacu" ];

  # Enable automatic updates (optional but good for servers)
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  system.stateVersion = "25.05"; # Did you read the comment?
}
