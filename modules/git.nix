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
    aliases = {
      # mixed: unstages the changes but keeps them in your working directory
      # other options: soft, hard
      undoco = "reset HEAD~1 --mixed";
    };
  };
}
