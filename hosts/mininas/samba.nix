# /etc/nixos/samba.nix
{ config, pkgs, ... }:

{
  # Ensure the share directory has correct ownership/permissions
  systemd.tmpfiles.rules = [
    "d /backups/Diego 0770 syncs users -"
  ];

  services.samba = {
    enable = true;
    openFirewall = true; # opens 445/139/137/138 automatically

    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "nixos-backup";
        "netbios name" = "NIXOS-BACKUP";
        "security" = "user";
        "map to guest" = "never";

        "server min protocol" = "SMB2";
        "server smb encrypt" = "desired";

        "log file" = "/var/log/samba/log.%m";
        "log level" = "1";
      };

      diego-backups = {
        "path" = "/backups/Diego";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "syncs";
        "force user" = "syncs";
        "force group" = "users";
        "create mask" = "0660";
        "directory mask" = "0770";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}