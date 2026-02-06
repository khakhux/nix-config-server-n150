{
  description = "NixOS from Scratch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
  };

  outputs = { self, nixpkgs, home-manager, nixos-wsl, ... }:
    let
      system = "x86_64-linux";
      users = import ./users.nix;
      
      mkHost = hostName: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${hostName}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${users.mainUser} = import ./hosts/${hostName}/home.nix;
            home-manager.backupFileExtension = "backup";
          }
          nixos-wsl.nixosModules.default
        ];
      };
    in {
      nixosConfigurations = {
        server-docker-01 = mkHost "server-docker-01";
        mininas = mkHost "mininas";
        currolaptop = mkHost "currolaptop";
        # Add more hosts like this:
        # other-host = mkHost "other-host";
      };
    };
}
