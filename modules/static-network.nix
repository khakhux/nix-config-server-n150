{ interfaceName, ipAddress, gateway ? "192.168.1.1", nameservers ? [ "192.168.1.243" "8.8.8.8" ] }:

{ config, ... }:

{
  networking.interfaces = {
    # Use the dynamic key syntax for interface name
    "${interfaceName}" = {
      useDHCP = false;
      ipv4.addresses = [{
        address = ipAddress;
        prefixLength = 24;
      }];
    };
  };

  networking.defaultGateway = gateway;
  networking.nameservers = nameservers;
}