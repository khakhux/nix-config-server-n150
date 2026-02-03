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
      ports.RTSP
      ports.TRANSMISSION
      ports.TRANSMISSION_WEB
      ports.NFS
      ports.MUSIC_ASSISTANT_UI
      ports.MUSIC_ASSISTANT_WEB_SOCKET
      ports.MUSIC_ASSISTANT_SERVICE_PORT
      #ports.MUSIC_ASSISTANT_SNAPCAST_STREAM
      #ports.MUSIC_ASSISTANT_SNAPCAST_CONTROL
      ports.MUSIC_ASSISTANT_GOOGLE_CAST_TCP
      ports.JELLYFIN
      ports.RCLONE
      ports.MITM_PROXY
      ports.DUPLICATI
      ports.PINCHFLAT
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

  environment.systemPackages = with pkgs; [
    mitmproxy
    jq
  ];

  users.users.${users.mainUser}.openssh.authorizedKeys.keys = [   
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDCuwzJh2u6enFsZNf2t9d0O8GQ8OetDufLpaHMsolph rpi42@email.com"
  ];

  users.groups.syncs = {};

  users.users.syncs = {
    isNormalUser = true;
    group = "syncs";
    extraGroups = [ "docker" ];
    # Setting the shell to nologin prevents interactive SSH shell access
    shell = pkgs.shadow; 
    openssh.authorizedKeys.keyFiles = [
      ../../ssh-keys/id_ed25519_mi9t.pub
      ./docker_data_argea.pub
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
    "L+ /datos - - - - /nvme1/datos"
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
      "50 22 * * * ${users.mainUser} /docker_data/scripts/backup/bak_git.sh >> /home/${users.mainUser}/bak_git.log 2>&1"
      #"30 23 * * * ${users.mainUser} /docker_data/scripts/rclone/sync.sh || /docker_data/scripts/notify.sh 'error sinc drive'"
      "00 23 * * * ${users.mainUser} /docker_data/ytdl-sub/run.sh >> /home/${users.mainUser}/ytdl-sub.log 2>&1"
      "50 23 * * * ${users.mainUser} /docker_data/ytdl-sub/mv-watchlater-movil.sh >> /home/${users.mainUser}/watchlater-movil.log 2>&1"
    ];
  };

  # Enable automatic updates (optional but good for servers)
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  system.stateVersion = "25.05"; # Did you read the comment?
}
