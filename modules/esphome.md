### `modules/esphome.nix`

```
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    esphome
  ];

  users.users.your-username.extraGroups = [
    "dialout"
  ];
}
```

 Replace `your-username` with your actual NixOS username.

 Then import it from your existing configuration:

```
{
  imports = [
    ./modules/esphome.nix
  ];

  # ...your existing configuration...
}
```

 Then:

```
sudo nixos-rebuild switch --flake .#your-hostname
```

 After logging out/in, check:

```
esphome version
```

 and:

```
groups
```

 You should see `dialout`.

 ### A slightly better version

 If you already have `extraGroups` configured elsewhere, **don't define it twice**, because Nix will merge the lists but you may accidentally make the module less reusable.

 I'd therefore make the module accept the username as an option:

```
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
```

 Then in your host configuration:

```
{
  imports = [
    ./modules/esphome.nix
  ];

  services.esphome = {
    enable = true;
    user = "your-username";
  };
}
```

 This gives you a reusable module that you can enable on whichever NixOS machine you want.
