{ config, pkgs, ... }:

{
  imports = [
    ../../modules/common-home.nix
    ../../modules/git.nix
    #(import ../../modules/nvim/neovim.nix {
    #  inherit config pkgs;
    #})
  ];

  home.packages = with pkgs; [    
    mc # midnight commander, similar to norton commander
  ];
}
