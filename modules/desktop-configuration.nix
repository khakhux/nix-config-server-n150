{ config, ... }:

{

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  # OR
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
    # If you want to use JACK applications, uncomment this
  #   jack.enable = true;

  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # KDE Plasma
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Allow login via GUI
  # services.xserver.displayManager.autoLogin.enable = false;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "es";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # console.keyMap = "es"

  # Enable RDP Access
  # services.xrdp.enable = true;
  # services.xrdp.defaultWindowManager = "startplasma-x11";

  # Desktop basic programs
  # programs.firefox.enable = true;
  # OR
  # environment.systemPackages = with pkgs; [
  #   firefox
  #   kate
  # alacritty is a fast and declaratively configured terminal emulator
  # https://alacritty.org/
  #   alacritty
  # ];
}