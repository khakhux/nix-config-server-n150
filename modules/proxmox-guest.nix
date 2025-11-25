# modules/proxmox-guest.nix
{ config, pkgs, ... }:

{
  services.qemuGuest.enable = true;
}
