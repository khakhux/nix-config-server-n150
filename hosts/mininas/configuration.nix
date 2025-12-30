{ config, lib, pkgs, ... }:

let
  ports = import ../../ports.nix;
  ips = import ../../ips.nix;
  users = import ../../users.nix;
  mainUser = users.mainUser;
in

{
  imports =
    [
      ./hardware-configuration.nix
      (import ../../modules/common-configuration.nix {
        inherit config lib pkgs;
        interfaceName = "enp1s0";
        ipAddress = ips.mininas;
        extraGroups = "docker";
      })
      ../../modules/docker.nix
      #(import ./syncthing.nix mainUser)
    ];

  networking = {
    hostName = "mininas";
    networkmanager.enable = true;
    firewall.enable = true;
    firewall.checkReversePath = "loose";
    firewall.allowedTCPPorts = [ 
      ports.SSH
      ports.FRIGATE
      ports.TRANSMISSION
      ports.TRANSMISSION_WEB
      ports.NFS
      ports.MUSIC_ASSISTANT_UI
      ports.MUSIC_ASSISTANT_WEB_SOCKET
      ports.MUSIC_ASSISTANT_SERVICE_PORT
      #ports.MUSIC_ASSISTANT_SNAPCAST_STREAM
      #ports.MUSIC_ASSISTANT_SNAPCAST_CONTROL
      ports.JELLYFIN
      ports.RCLONE
    ];
    firewall.allowedUDPPorts = [ 
      ports.TRANSMISSION 
      ports.MUSIC_ASSISTANT_UDP_MDNS
      ports.MUSIC_ASSISTANT_UDP_SSDP
    ];
  };

  # Allow Transmission web interface only from your phone's static IP
  #extraCommands = ''
  #  iptables -A nixos-fw -p tcp --dport 9091 -s 192.168.1.50 -j nixos-fw-accept
  #'';

 # Enable WireGuard kernel module
  boot.kernelModules = [ "wireguard" ];

  # Allow Docker to use necessary capabilities
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.src_valid_mark" = 1;
  };

  # Install WireGuard tools on host (optional, for debugging)
  #environment.systemPackages = with pkgs; [
  #  wireguard-tools
  #];

  users.groups.syncs = {};

  users.users.syncs = {
    isNormalUser = true;
    group = "syncs";
    # Setting the shell to nologin prevents interactive SSH shell access
    shell = pkgs.shadow; 
    openssh.authorizedKeys.keyFiles = [
      ../../ssh-keys/id_ed25519_mi9t.pub
    ];
  };

  ssh.allowedUsers = [ "${users.mainUser}" "syncs" ];
  
  services.openssh = {
    extraConfig = ''
      # Start restriction for the syncs user
      Match User syncs
        ForceCommand internal-sftp
        AllowTcpForwarding no
        X11Forwarding no
        AllowAgentForwarding no

      Match All
    '';
  };

  systemd.tmpfiles.rules = [
    "L+ /media - - - - /nvme1/media"
    "L+ /backups - - - - /nvme2/backups"
  ];

  # fsid=0 so it works with nfs4 and doesn't need to open other ports
  # client must mount with mininas:/
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /media/Music/Temas 192.168.1.0/24(ro,sync,no_subtree_check,fsid=0)
  '';

  services.cron = {
    enable = true;
    systemCronJobs = [
      "50 22 * * * cacu /bin/bash /docker_data/scripts/backup/bak_git.sh >> /home/cacu/bak_git.log 2>&1"
      #"30 23 * * * cacu /docker_data/scripts/rclone/sync.sh || /docker_data/scripts/notify.sh 'error sinc drive'"
    ];
  };

  # Enable automatic updates (optional but good for servers)
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  system.stateVersion = "25.05"; # Did you read the comment?
}
