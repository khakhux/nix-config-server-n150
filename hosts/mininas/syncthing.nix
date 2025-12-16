mainUser:

{ config, pkgs, ... }:

{
  # https://wiki.nixos.org/wiki/Syncthing
  services.syncthing = {
    enable = true;
    user = mainUser; # syncthings process will run as this user
    dataDir = "/home/${mainUser}"; # Path to internal database, indexes, and metadata about synced files
    configDir = "/home/${mainUser}/.config/syncthing"; # (config.xml, certificates, device keys)
    overrideDevices = true; # When false, you can add devices through the web GUI
    overrideFolders = false; # Same for shared folders
    
    settings = {
      gui = {
        # ssh -L 8384:localhost:8384 user@your-mini-pc-ip
        address =  "127.0.0.1:8384";
        #address = "0.0.0.0:8384";  # Listen on all interfaces instead of just localhost
        #user = "${mainUser}";  # IMPORTANT: Set this
        #password = "yourguipassword";  # use sops or ommit and set address to localhost and use ssh user
      };
      options = {
        urAccepted = -1; # no telemetry
        openDefaultPorts = true;
        natEnabled = false;  # Disable NAT-PMP/UPnP
        localAnnounceEnabled = true;   # Find devices on LAN
        globalAnnounceEnabled = false; # Don't use public discovery
        relaysEnabled = false;         # Direct connections only
      };
      devices = import ./syncthing-devices.nix;
      folders = import ./syncthing-folders.nix;
    };
  };      
}