{ config, pkgs, ... }:

{
  home.username = "cacu";
  home.homeDirectory = "/home/cacu";
  programs.git = {
    enable = true;
    userName = "cacu";
    userEmail = "cacu@email.com";
  };
  home.stateVersion = "25.05";
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/nix-config-server-n150#nixos";
    };
  };

home.packages = with pkgs; [    
    neovim
  ];

}
