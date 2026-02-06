{
  description = "Java Maven development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-jdk2102.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-maven386.url = "github:NixOS/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs, nixpkgs-jdk2102, nixpkgs-maven386 }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
        inherit system; 
        config.allowUnfree = true; 
      };
      
      # Import pinned JDK 21 from nixos-24.05
      pkgs-jdk2102 = import nixpkgs-jdk2102 { 
        inherit system; 
        config.allowUnfree = true; 
      };
      jdk21-pinned = pkgs-jdk2102.jdk21;
      
      # Import Maven 3.8.6 from nixos-22.11 and override to use pinned JDK 21
      pkgs-maven386 = import nixpkgs-maven386 { 
        inherit system; 
        config.allowUnfree = true; 
      };
      maven386-jdk21 = pkgs-maven386.maven.override { 
        jdk = jdk21-pinned; 
      };

      # Keystore Explorer with JDK 21
      keystore-explorer-jdk21 = pkgs.keystore-explorer.override {
        jdk = jdk21-pinned;
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        name = "java-maven-dev";
        
        buildInputs = [
          jdk21-pinned
          maven386-jdk21
          keystore-explorer-jdk21
        ];
        
        shellHook = ''
          echo "Java Development Environment"
          echo "=============================="
          java -version
          echo ""
          mvn -version
          echo ""
          echo "Environment variables:"
          echo "JAVA_HOME: $JAVA_HOME"
        '';
        
        # Set JAVA_HOME for tools that need it
        JAVA_HOME = "${jdk21-pinned}";
      };
    };
}
