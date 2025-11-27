# modules/proxmox-guest.nix
{ config, pkgs, ... }:

{
  services.qemuGuest.enable = true;

  # Proxmox VirtIO drivers and QEMU guest agent
  #boot.initrd.availableKernelModules = [ 
  #  "ata_piix" 
  #  "uhci_hcd" 
  #  "virtio_pci" 
  #  "virtio_scsi" 
  #  "sd_mod" 
  #  "sr_mod" 
  #];
  
}
