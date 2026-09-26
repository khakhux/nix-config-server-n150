{ config, lib, pkgs, ... }:

let
  cfg = config.services.esphome;
in
{
  options.services.esphome = {
    enable = lib.mkEnableOption "ESPHome CLI";

    user = lib.mkOption {
      type = lib.types.str;
      description = "User that should have access to ESP32 serial devices.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.esphome
    ];

    users.users.${cfg.user}.extraGroups = [
      "dialout"
    ];
  };
}
