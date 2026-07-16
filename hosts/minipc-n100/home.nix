{ config, pkgs, ... }:

{
  imports = [
    ../../modules/common-home.nix
    ../../modules/git.nix
  ];

}
