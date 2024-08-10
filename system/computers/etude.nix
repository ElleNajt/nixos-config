{ config, lib, pkgs, ... }:

{

  config = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    elle.is_vm = true;
    networking.hostName = "etude";
    time.timeZone = "America/New_York";
  };

}
