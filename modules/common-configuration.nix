# modules/common-configuration.nix
{ config, pkgs, interfaceName, ipAddress, extraGroups, ... }:

let
  staticNetwork = import ./static-network.nix {
    inherit interfaceName ipAddress;
  };
in

{
  imports = [
    staticNetwork
    ./hardened-ssh.nix
  ];
  
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "es_ES.UTF-8";
  console = {
    #   font = "Lat2-Terminus16";
    keyMap = "es";
    #   useXkbConfig = true; # use xkb.options in tty.
  };

  users.users.cacu = {
    isNormalUser = true;
    extraGroups = [ "wheel" extraGroups ]; # Enable 'sudo' for the user.
    openssh.authorizedKeys.keyFiles = [
      ../ssh-keys/id_ed25519_nixos.pub  # Note: relative path adjusted
    ];
    packages = with pkgs; [
      tree
    ];
  };

  programs.nix-ld.enable = true; # for remote access via vscode

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    tmux
  ];

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}