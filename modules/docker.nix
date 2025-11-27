{ config, pkgs, ... }:

{
  # Enable Docker and Compose
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # is this required?
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}