{ config, pkgs, ... }:

{
  imports = [
    ../../modules/common-home.nix
  ];

  home.packages = with pkgs; [
    firefox
  ];
}
