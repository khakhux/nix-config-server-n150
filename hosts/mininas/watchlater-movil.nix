{ config, pkgs, ... }:

let
  moveVideoScript = pkgs.writeScriptBin "move-video-files" (builtins.readFile ./move-video-files.sh);
  
  sourceDir = "/path/to/source";
  destDir = "/path/to/destination";
  keepCount = "10";
in
{
  # Make the script available system-wide
  environment.systemPackages = [ moveVideoScript ];

  systemd.services.move-video-files = {
    description = "Move video and nfo files keeping only 10 in source";
    
    environment = {
      SOURCE_DIR = sourceDir;
      DEST_DIR = destDir;
      KEEP_COUNT = keepCount;
    };
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${moveVideoScript}/bin/move-video-files";
      User = "your-username";  # Change this
      Group = "users";          # Change this if needed
    };
  };

  systemd.timers.move-video-files = {
    description = "Daily timer to move video files";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnCalendar = "daily";           # Run at midnight, or use "02:00" for 2 AM
      Persistent = true;               # Run missed jobs on boot
      RandomizedDelaySec = "5m";      # Add random delay to avoid load spikes
    };
  };
}