{ config, lib, pkgs, ... }:

let
  staticNetwork = import ./modules/static-network.nix {
    interfaceName = "ens18";
    ipAddress = "192.168.1.248";
  };
in
{
  imports =
    [
      ./hardware-configuration.nix
    staticNetwork
    ./modules/hardened-ssh.nix
    ./modules/common-configuration.nix    
    ];

  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
  };

  ssh.allowedUsers = [ "cacu" ];

  services.qemuGuest.enable = true;

  system.stateVersion = "25.05"; # Did you read the comment?
}

