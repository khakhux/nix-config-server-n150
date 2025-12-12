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
        interfaceName = "enp1s0";
        ipAddress = ips.mininas;
        extraGroups = "docker";
      })
      ../../modules/docker.nix
    ];

  networking = {
    hostName = "mininas";
    networkmanager.enable = true;
    firewall.enable = false;
    firewall.allowedTCPPorts = [ ports.SSH ports.FRIGATE ];
  };

 # Enable WireGuard kernel module
  boot.kernelModules = [ "wireguard" ];

  # Allow Docker to use necessary capabilities
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.src_valid_mark" = 1;
  };

  # Install WireGuard tools on host (optional, for debugging)
  #environment.systemPackages = with pkgs; [
  #  wireguard-tools
  #];

  ssh.allowedUsers = [ "cacu" ];

  # Enable automatic updates (optional but good for servers)
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  system.stateVersion = "25.05"; # Did you read the comment?
}
