{ pkgs, ... }:

{
  # Create radicale config directory and empty htpasswd file if missing
  systemd.tmpfiles.rules = [
    "d /etc/radicale 0750 radicale radicale -"
    "f /etc/radicale/users 0640 radicale radicale -"
  ];

  services.radicale = {
    enable = true;
    settings = {
      server = {
        hosts = [ "0.0.0.0:5232" ];
      };
      auth = {
        type = "htpasswd";
        htpasswd_filename = "/etc/radicale/users";
        htpasswd_encryption = "bcrypt";
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 5232 ];

  #services.tailscale = {
  #  enable = true;
  #};

  #systemd.services.tailscale-serve-radicale = {
  #  description = "Configure Tailscale serve for Radicale";
  #  after = [ "tailscaled.service" "radicale.service" "network-online.target" ];
  #  wants = [ "tailscaled.service" "radicale.service" "network-online.target" ];
  #  wantedBy = [ "multi-user.target" ];
  #  serviceConfig = {
  #    Type = "oneshot";
  #    RemainAfterExit = true;
  #    ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg http://127.0.0.1:5232";
  #    ExecStop = "${pkgs.tailscale}/bin/tailscale serve off http://127.0.0.1:5232";
  #  };
  #};

  environment.systemPackages = with pkgs; [
    apacheHttpd  # provides htpasswd
  ];

  system.activationScripts.radicaleUserHint = {
    text = ''
      echo ""
      echo "-------------------------------------------------------"
      echo "  Radicale: to add or update a user, run:"
      echo "  sudo htpasswd -B /etc/radicale/users <username>"
      echo "-------------------------------------------------------"
      echo ""
    '';
    deps = [];
  };
}