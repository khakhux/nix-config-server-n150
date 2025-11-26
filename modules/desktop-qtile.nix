# qtile window manager config
# copied from https://github.com/tonybanters/nixos-from-scratch/blob/master/configuration.nix
# check also https://github.com/tonybanters/nixos-from-scratch/blob/master/home.nix
# and https://github.com/tonybanters/nixos-from-scratch/tree/master/config for individual config files

{ config, ... }:

{

  services.displayManager.ly.enable = true;
  services.xserver = {
    enable = true;
    windowManager.qtile.enable = true;
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
    #displayManager.sessionCommands = ''
    #  xwallpaper --zoom ~/nixos-dotfiles/walls/wall1.png
    #'';
    #extraConfig = ''
    #  	Section "Monitor"
    #  	  Identifier "Virtual-1"
    #  	  Option "PreferredMode" "1920x1080"
    #  	EndSection
    #'';
  };

  # lightweight compositor for X11, adds visual effects and fixes rendering issues when using a standalone window manager
  services.picom.enable = true;

  # Makes command-line tools alacritty display icons properly
  # It could be used with any window manager although full ones like plasma include their own
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    neovim
    wget
    git
    # alacritty is a fast and declaratively configured terminal emulator
    # https://alacritty.org/
    alacritty
  ];

  
}