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
    shellAliases = { };
    initExtra = ''
      nrs() {
        local host=$(hostname)
        sudo nixos-rebuild switch --flake ~/nix-config-server-n150#"$host"
      }
    '';
  };

  home.packages = with pkgs; [    
    neovim
  ];
}
