{
  description = "NixOS from Scratch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      
      mkHost = hostName: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${hostName}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.cacu = import ./home.nix;
            home-manager.backupFileExtension = "backup";
          }
        ];
      };
    in {
      nixosConfigurations = {
        nixos = mkHost "nixos";
        # Add more hosts like this:
        # other-host = mkHost "other-host";
      };
    };
}
