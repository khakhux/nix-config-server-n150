# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, nixpkgs-maven386, nixpkgs-jdk2102, ... }:

let
  ips = import ../../ips.nix;
  users = import ../../users.nix;
  mainUser = users.mainUser;
  
  # Import JDK 21.0.2 from specific nixpkgs version
  pkgs-jdk2102 = import nixpkgs-jdk2102 { 
    inherit (pkgs) system; 
    config.allowUnfree = true;
  };
  jdk21-pinned = pkgs-jdk2102.jdk21;
  
  # Import Maven 3.8.6 and override to use pinned JDK 21
  pkgs-maven386 = import nixpkgs-maven386 { 
    inherit (pkgs) system; 
    config.allowUnfree = true;
  };
  maven386-jdk21 = pkgs-maven386.maven.override { 
    jdk = jdk21-pinned; 
  };
in

{
  imports = [
      ../../modules/docker.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode"
  ];

  wsl.enable = true;
  wsl.defaultUser = "cacu";

  networking = {
    networkmanager.enable = true;
    hostName = "currolaptop";
  };

  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "es_ES.UTF-8";
  console = {
    #   font = "Lat2-Terminus16";
    keyMap = "es";
    #   useXkbConfig = true; # use xkb.options in tty.
  };

  users.users.cacu = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # Enable 'sudo' for the user.
  };

  security.pki.certificateFiles = [
    cacerts/CARaiz.pem
  ];

  environment.systemPackages = with pkgs; [
    #https://mynixos.com/nixpkgs/package/
    pkgs.wget
    # https://nixos.wiki/wiki/Java#Overriding_java_jks_Certificate_Store
    jdk21-pinned
    # https://ryantm.github.io/nixpkgs/languages-frameworks/maven/
    # Maven 3.8.6 configured to use JDK 21
    maven386-jdk21
    vscode
    jetbrains.idea-ultimate #/ jetbrains.idea-community
    #dbvisualizer
    #keystore-explorer
    #node.js
    #python
    #postman
    #soapui
    #wireshark
    #gh  # GitHub CLI
    jq
    firefox
    nil          # Nix LSP server for code analysis
    nixpkgs-fmt  # Nix Formatter (alternative is alejandra)
    #keepassxc
    #zathura / mupdf #pdf viewer
    #arduino
    #flameshot # screenshot tool
    #nomacs # image viewer 
    #obsidian
    # wrapper with specific JVM options example
    #(writeShellScriptBin "idea" ''
    #  exec ${jetbrains.idea-ultimate}/bin/idea-ultimate \
    #    -Dsun.java2d.xrender=false \
    #    -Dsun.java2d.opengl=false \
    #    -Dawt.useSystemAAFontSettings=lcd \
    #    "$@"
    #'')
  ];

  #system.activationScripts.make-jdk-dir = "mkdir -p /usr/lib/jvm/default-jdk";
  #fileSystems."/usr/lib/jvm/default-jdk" = {
  #  device = "${pkgs.jdk}/lib/openjdk";
  #  options = [ "bind" ];
  #};  
  
  virtualisation.docker = {
    enable = true;

    daemon.settings = {
      "registry-mirrors" = [
        "https://docker.m.daocloud.io"
      ];
    };
  };

  programs.nix-ld.enable = true; # for remote access via vscode

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05"; # Did you read the comment?
}
