{
  description = "NixOS from Scratch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
  };

  outputs = { self, nixpkgs, home-manager, nix-index-database, nixos-wsl, ... }:
    let
      system = "x86_64-linux";
      users = import ./users.nix;
      
      mkHost = hostName: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${hostName}/configuration.nix
          nix-index-database.nixosModules.default
          # optional to also wrap and install comma
          # { programs.nix-index-database.comma.enable = true; }
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
