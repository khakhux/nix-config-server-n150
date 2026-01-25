# configuration.nix or a separate module

{ config, pkgs, lib, ... }:

let
  # Define your containers per host
  encryptedContainers = {
    "storage" = {
      containerPath = "/data/encrypted-storage.img";
      mountPoint = "/mnt/encrypted-storage";
      mapperName = "encrypted-storage";
      autoUmountAfter = "30min";
      useYubikey = true;  # Try YubiKey authentication
      yukikeyOnly = false;  # Fall back to password if YubiKey fails
    };
    "personal" = {
      containerPath = "/data/encrypted-personal.img";
      mountPoint = "/mnt/encrypted-personal";
      mapperName = "encrypted-personal";
      autoUmountAfter = "1h";
      useYubikey = true;
      yukikeyOnly = true;  # Only allow YubiKey, no password fallback
    };
    "backup" = {
      containerPath = "/backup/encrypted-backup.img";
      mountPoint = "/mnt/encrypted-backup";
      mapperName = "encrypted-backup";
      autoUmountAfter = null;
      useYubikey = false;  # Password only for this container
      yukikeyOnly = false;
    };
  };

  # Path to the luks-manager script
  luksManager = pkgs.writeScriptBin "luks-manager" (builtins.readFile ./luks-manager.sh);

  # Helper to determine yubikey mode
  getYubikeyMode = cfg:
    if !cfg.useYubikey then "no"
    else if cfg.yukikeyOnly then "yes"
    else "auto";

in {
  # Install required packages
  environment.systemPackages = [ 
    pkgs.cryptsetup
    pkgs.yubikey-manager         # For YubiKey management (ykman)
    pkgs.yubikey-personalization # For challenge-response (ykchalresp)
    pkgs.systemd                 # Includes systemd-cryptenroll for FIDO2
    luksManager
  ];

  # Enable pcscd service for YubiKey support
  services.pcscd.enable = true;

  # Enable udev rules for YubiKey
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # Create convenience scripts for each configured container
  environment.systemPackages = lib.mapAttrsToList (name: cfg: 
    pkgs.writeScriptBin "mount-${name}" ''
      #!${pkgs.bash}/bin/bash
      ${luksManager}/bin/luks-manager mount "${cfg.containerPath}" "${cfg.mountPoint}" "${cfg.mapperName}" "${getYubikeyMode cfg}"
    ''
  ) encryptedContainers ++
  lib.mapAttrsToList (name: cfg:
    pkgs.writeScriptBin "umount-${name}" ''
      #!${pkgs.bash}/bin/bash
      ${luksManager}/bin/luks-manager umount "${cfg.mountPoint}"
    ''
  ) encryptedContainers ++
  lib.mapAttrsToList (name: cfg:
    pkgs.writeScriptBin "setup-yubikey-${name}" ''
      #!${pkgs.bash}/bin/bash
      ${luksManager}/bin/luks-manager setup-yubikey "${cfg.containerPath}"
    ''
  ) encryptedContainers ++
  [
    # Overall status script
    (pkgs.writeScriptBin "encrypted-status" ''
      #!${pkgs.bash}/bin/bash
      echo "Configured Encrypted Containers:"
      echo "================================"
      echo ""
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: cfg: ''
        echo "Container: ${name}"
        echo "  Path: ${cfg.containerPath}"
        echo "  Mount: ${cfg.mountPoint}"
        echo "  YubiKey: ${if cfg.useYubikey then (if cfg.yukikeyOnly then "Required" else "Preferred") else "Disabled"}"
        ${luksManager}/bin/luks-manager status "${cfg.mapperName}" 2>/dev/null || echo "  Status: NOT MOUNTED"
        echo ""
      '') encryptedContainers)}
    '')
    
    # Helper script to setup YubiKey for all containers
    (pkgs.writeScriptBin "setup-all-yubikeys" ''
      #!${pkgs.bash}/bin/bash
      echo "Setting up YubiKey authentication for all containers"
      echo "===================================================="
      echo ""
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: cfg:
        lib.optionalString cfg.useYubikey ''
          echo "Setting up YubiKey for: ${name}"
          ${luksManager}/bin/luks-manager setup-yubikey "${cfg.containerPath}" || echo "Failed to setup ${name}"
          echo ""
        ''
      ) encryptedContainers)}
    '')
  ];

  # Create systemd services for each container (optional, for systemd management)
  systemd.services = lib.mapAttrs' (name: cfg:
    lib.nameValuePair "encrypted-mount-${name}" {
      description = "Mount encrypted container ${name}";
      wantedBy = [ ];  # Don't auto-start
      
      # Ensure YubiKey is accessible
      after = [ "pcscd.service" ];
      wants = lib.optional cfg.useYubikey "pcscd.service";
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        
        ExecStart = "${luksManager}/bin/luks-manager mount ${cfg.containerPath} ${cfg.mountPoint} ${cfg.mapperName} ${getYubikeyMode cfg}";
        ExecStop = "${luksManager}/bin/luks-manager umount ${cfg.mountPoint}";
      };
    }
  ) encryptedContainers;

  # Create auto-unmount timers for containers that have autoUmountAfter set
  systemd.timers = lib.mapAttrs' (name: cfg:
    lib.nameValuePair "encrypted-auto-umount-${name}" (
      lib.mkIf (cfg.autoUmountAfter != null) {
        description = "Auto-unmount encrypted container ${name} after inactivity";
        wantedBy = [ "timers.target" ];
        
        timerConfig = {
          OnUnitActiveSec = cfg.autoUmountAfter;
          Unit = "encrypted-auto-umount-${name}.service";
        };
      }
    )
  ) encryptedContainers;

  systemd.services = lib.mapAttrs' (name: cfg:
    lib.nameValuePair "encrypted-auto-umount-${name}" (
      lib.mkIf (cfg.autoUmountAfter != null) {
        description = "Auto-unmount encrypted container ${name}";
        
        serviceConfig = {
          Type = "oneshot";
          
          # Only unmount if mounted
          ExecStart = pkgs.writeShellScript "auto-umount-${name}" ''
            if mountpoint -q "${cfg.mountPoint}"; then
              echo "Auto-unmounting ${name} due to inactivity..."
              ${luksManager}/bin/luks-manager umount "${cfg.mountPoint}"
            fi
          '';
        };
      }
    )
  ) encryptedContainers;

  # Optional: Add udev rules to auto-mount when YubiKey is inserted
  # Uncomment if you want this behavior
  # services.udev.extraRules = ''
  #   # Auto-mount when YubiKey is inserted
  #   ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1050", TAG+="systemd", ENV{SYSTEMD_WANTS}="yubikey-inserted.service"
  # '';
  # 
  # systemd.services.yubikey-inserted = {
  #   description = "YubiKey inserted notification";
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = pkgs.writeShellScript "yubikey-inserted" ''
  #       # Notify user that YubiKey is available
  #       # Could automatically mount certain containers here
  #       echo "YubiKey detected"
  #     '';
  #   };
  # };
}