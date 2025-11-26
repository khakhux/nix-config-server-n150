{ config, ... }:

{

  # KDE Plasma
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
  }
  
  # Enable RDP Access
  services.xrdp = {
    enable = true; # optional
    defaultWindowManager = "startplasma-x11";
  }
}