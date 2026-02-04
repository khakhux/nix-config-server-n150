{ config, pkgs, ... }:

{
  imports = [
    ../../modules/common-home.nix
    ../../modules/git.nix
  ];

  home.packages = with pkgs; [
    firefox
  ];
}
