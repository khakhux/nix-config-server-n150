{ config, pkgs, lib, ... }:

let
  # Define your containers per host
  encryptedContainers = {
    "storage" = {
      containerPath = "/data/encrypted-storage.img";
      mountPoint = "/mnt/encrypted-storage";
      mapperName = "encrypted-storage";
      autoUmountAfter = "30min";  # Optional: auto-unmount after inactivity
    };
    "personal" = {
      containerPath = "/data/encrypted-personal.img";
      mountPoint = "/mnt/encrypted-personal";
      mapperName = "encrypted-personal";
      autoUmountAfter = "1h";
    };
    "backup" = {
      containerPath = "/backup/encrypted-backup.img";
      mountPoint = "/mnt/encrypted-backup";
      mapperName = "encrypted-backup";
      # No auto-unmount for this one
      autoUmountAfter = null;
    };
  };

  # Path to the luks-manager script
  luksManager = pkgs.writeScriptBin "luks-manager" (builtins.readFile ./luks-manager.sh);

in {
  # Install the luks-manager script system-wide
  environment.systemPackages = [ 
    pkgs.cryptsetup
    luksManager
  ];

  # Create convenience aliases/scripts for each configured container
  environment.systemPackages = lib.mapAttrsToList (name: cfg: 
    pkgs.writeScriptBin "mount-${name}" ''
      #!${pkgs.bash}/bin/bash
      ${luksManager}/bin/luks-manager mount "${cfg.containerPath}" "${cfg.mountPoint}" "${cfg.mapperName}"
    ''
  ) encryptedContainers ++
  lib.mapAttrsToList (name: cfg:
    pkgs.writeScriptBin "umount-${name}" ''
      #!${pkgs.bash}/bin/bash
      ${luksManager}/bin/luks-manager umount "${cfg.mountPoint}"
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
        ${luksManager}/bin/luks-manager status "${cfg.mapperName}" 2>/dev/null || echo "  Status: NOT MOUNTED"
        echo ""
      '') encryptedContainers)}
    '')
  ];

  # Create systemd services for each container (optional, for systemd management)
  systemd.services = lib.mapAttrs' (name: cfg:
    lib.nameValuePair "encrypted-mount-${name}" {
      description = "Mount encrypted container ${name}";
      wantedBy = [ ];  # Don't auto-start
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        
        ExecStart = "${luksManager}/bin/luks-manager mount ${cfg.containerPath} ${cfg.mountPoint} ${cfg.mapperName}";
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
}