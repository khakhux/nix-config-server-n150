# modules/hardened-ssh.nix
{ config, lib, ... }:

with lib;

{
  options = {
    ssh.allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [ "cacu" ];
      description = "List of users allowed to log in via SSH.";
    };
  };

  config = {
    services.openssh = {
      enable = true;

      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        X11Forwarding = false;
        AllowTcpForwarding = "yes"; # for vscode access
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
        MaxAuthTries = 3;
        LoginGraceTime = "30s";
        PermitEmptyPasswords = false;
        UseDns = false;
        Compression = "no";
        KexAlgorithms = [ "curve25519-sha256" ];
        Ciphers = [ "chacha20-poly1305@openssh.com" ];
        Macs = [ "hmac-sha2-512-etm@openssh.com" ];
      };

      openFirewall = true;

      extraConfig = mkIf (config.ssh.allowedUsers != []) ''
        AllowUsers ${concatStringsSep " " config.ssh.allowedUsers}
      '';
    };
  };
}
