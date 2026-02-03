{ config, pkgs, ... }:

let
  users = import ../users.nix;
in

{
  home.username = users.mainUser;
  home.homeDirectory = "/home/${users.mainUser}";
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
    mc # midnight commander, similar to norton commander
  ];
}
