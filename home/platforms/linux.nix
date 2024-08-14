{ config, lib, pkgs, ... }:

{

  home.packages = with pkgs; [
    # Desktop stuff
    feh
    chromium
    picom
    signal-desktop
    apvlv
    vlc
    gimp

    # System utilities
    powertop
    usbutils
    pciutils
    gdmap
    lsof
    tree
    nmap
    iftop

    # Security
    gnupg
    keybase
    openssl
    yubikey-manager

  ];
}
