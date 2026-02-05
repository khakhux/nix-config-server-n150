{
  description = "NixOS from Scratch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    # Add nixpkgs with Maven 3.8.6
    nixpkgs-maven386.url = "github:NixOS/nixpkgs/nixos-22.11";
    # Add nixpkgs with JDK 21.0.2
    nixpkgs-jdk2102.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs, home-manager, nixos-wsl, nixpkgs-maven386, nixpkgs-jdk2102, ... }:
    let
      system = "x86_64-linux";
      users = import ./users.nix;
      
      mkHost = hostName: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit nixpkgs-maven386 nixpkgs-jdk2102;
        };
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
