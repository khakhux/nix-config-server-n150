# modules/hardened-ssh.nix
{ config, lib, pkgs, ... }:

with lib;

let
  users = import ../users.nix;
in

{
  options = {
    ssh.allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [ "${users.mainUser}" ];
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
        UsePAM = true;
        #AuthenticationMethods = "publickey,keyboard-interactive:pam";
        AuthenticationMethods = "publickey"; # disable 2FA
        #KbdInteractiveAuthentication = true;
        #PubkeyAuthentication = "yes";
        #ChallengeResponseAuthentication = "yes";
      };

      openFirewall = true;

      extraConfig = mkIf (config.ssh.allowedUsers != []) ''
        AllowUsers ${concatStringsSep " " config.ssh.allowedUsers}
      '';
    };

    # Enable PAM for 2FA support
    #security.pam.services.sshd.googleAuthenticator.enable = true;

    # Install google-authenticator package
    #environment.systemPackages = with pkgs; [
    #  google-authenticator
    #];
  };
}
