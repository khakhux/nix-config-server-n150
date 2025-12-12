{ config, pkgs, ... }:

let
  users = import ../users.nix;
in

{
  home.username = users.mainUser;
  home.homeDirectory = "/home/${users.mainUser}";
  programs.git = {
    enable = true;
    userName = users.mainUser;
    userEmail = users.mainUserEmail;
    extraConfig = {
      pull.rebase = false;
    };
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
    mc # midnight commander, similar to norton commander
  ];
}
