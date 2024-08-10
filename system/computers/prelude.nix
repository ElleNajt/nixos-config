{ config, lib, pkgs, ... }:

{

  networking.hostName = "prelude";
  config.elle.is_vm = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "America/New_York";
}
