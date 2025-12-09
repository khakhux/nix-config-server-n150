{ config, lib, pkgs, ... }:

let
  ports = import ../../ports.nix;
  ips = import ../../ips.nix;
in

{
  imports =
    [
      ./hardware-configuration.nix
      (import ../../modules/common-configuration.nix {
        inherit config lib pkgs;
        interfaceName = "enp0s13f0u2u1";
        ipAddress = ips.mininas;
        extraGroups = "docker";
      })
      ../../modules/docker.nix
    ];

  networking = {
    hostName = "mininas";
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
