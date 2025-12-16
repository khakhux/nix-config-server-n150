{
  "transmission-watch" = {
    path = "/nvme2/transmission/watch/";
    devices = [ "mi9t" ];
    ignorePerms = true; # If true, don't sync file permissions (useful for cross-platform)
    type = "receiveonly";
  };
}
