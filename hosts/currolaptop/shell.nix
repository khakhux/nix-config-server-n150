# Development shell with pinned Java 21 and Maven 3.8.6
# Usage: nix-shell
# Or add to direnv: use nix

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  # Pin specific nixpkgs versions for Java and Maven
  nixpkgs-jdk2102 = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-24.05.tar.gz";
    sha256 = "0zydsqiaz8qi4zd63zsb2gij2p614cgkcaisnk11wjy3nmiq0x1s";
  };
  
  nixpkgs-maven386 = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-22.11.tar.gz";
  };

  # Import pinned JDK 21 from nixos-24.05
  pkgs-jdk2102 = import nixpkgs-jdk2102 { 
    inherit (pkgs) system; 
    config.allowUnfree = true;
  };
  jdk21-pinned = pkgs-jdk2102.jdk21;
  
  # Import Maven 3.8.6 from nixos-22.11 and override to use pinned JDK 21
  pkgs-maven386 = import nixpkgs-maven386 { 
    inherit (pkgs) system; 
    config.allowUnfree = true;
  };
  maven386-jdk21 = pkgs-maven386.maven.override { 
    jdk = jdk21-pinned; 
  };

  # Keystore Explorer with JDK 21
  keystore-explorer-jdk21 = pkgs.keystore-explorer.override {
    jdk = jdk21-pinned;
  };
in

pkgs.mkShell {
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
  #JAVA_HOME = "${jdk21-pinned}";
}
