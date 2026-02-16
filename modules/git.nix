{ config, pkgs, ... }:

let
  users = import ../users.nix;
in

{
  programs.git = {
    enable = true;
    userName = users.mainUser;
    userEmail = users.mainUserEmail;
    extraConfig = {
      pull.rebase = false;
      init.defaultBranch = "main";
    };
  };
}
