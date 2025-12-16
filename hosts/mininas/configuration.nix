{ config, lib, pkgs, ... }:

let
  ports = import ../../ports.nix;
  ips = import ../../ips.nix;
  users = import ../../users.nix;
  mainUser = users.mainUser;
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
      (import ./syncthing.nix mainUser)
    ];

  networking = {
    hostName = "mininas";
    networkmanager.enable = true;
    firewall.enable = true;
    firewall.checkReversePath = "loose";
    firewall.allowedTCPPorts = [ 
      ports.SSH
      ports.FRIGATE
      ports.TRANSMISSION
      ports.TRANSMISSION_WEB
    ];
    firewall.allowedUDPPorts = [ 
      ports.TRANSMISSION 
    ];
  };

  # Allow Transmission web interface only from your phone's static IP
  #extraCommands = ''
  #  iptables -A nixos-fw -p tcp --dport 9091 -s 192.168.1.50 -j nixos-fw-accept
  #'';

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

  ssh.allowedUsers = [ "${users.mainUser}" ];

  # Enable automatic updates (optional but good for servers)
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  system.stateVersion = "25.05"; # Did you read the comment?
}
