{ config, pkgs, ... }:

let
  mavenSettingsRepo = pkgs.fetchgit {
    url = "git@gitlab.central.sepg.minhac.age:div_4/administracion-digital/firma-electronica/metodologia/metodologia.git";
    rev = "master"; #"61841ca3b665c3e667b3a4bdac03db8217de5fb3";  # specific commit hash
    sha256 = "sha256-eNWSqXz54TZQAzLobmRiLqSYYkDtsCf2ArHsNS/ndHc=";
  };
in
{
  imports = [
    ../../modules/common-home.nix
  ];

  programs.git = {
    enable = true;
    userName = "sgen0291";
    userEmail = "crparedes@igae.hacienda.gob.es";
    extraConfig = {
      pull.rebase = false;
      init.defaultBranch = "main";
      http.sslCAInfo = "${config.home.homeDirectory}/.config/nixos-cacerts/ca-bundle.crt";
    };
  };

  home.file.".config/nixos-cacerts/ca-bundle.crt" = {
    source = pkgs.runCommand "ca-bundle.crt" {} ''
      cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > $out
      echo "" >> $out
      cat ${./cacerts/CARaiz.pem} >> $out
    '';
  };
  home.file.".m2/settings.xml".source = "${mavenSettingsRepo}/maven/settings.xml";
}
