# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

let sources = import ./nix/sources.nix;
in {

  imports = [
    ./hardware-configuration.nix
    ./system/vms.nix
    ./system/computers/etude.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    # font = "ter-i32b";
    # keyMap = "us";
    packages = with pkgs; [ terminus_font ];
    useXkbConfig = true; # use xkb.options in tty.
  };

  users.users.elle = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "a";
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [ vim firefox ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  system.stateVersion = "24.05"; # Did you read the comment?

  programs.dconf.enable = true;
  services.xserver = {

    enable = true;
    windowManager.i3.enable = true;

    # displayManager.sessionCommands = ''
    #   ${pkgs.xorg.xrdb}/bin/xrdb -merge <<EOF
    #     Xft.dpi: 96
    #   EOF
    # '';

  };

  hardware.opengl.enable = true;
  services.displayManager.defaultSession = "none+i3";
  services.pcscd.enable = true;
  nix.settings.experimental-features = [ "nix-command" ];
}
