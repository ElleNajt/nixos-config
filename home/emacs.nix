{ config, lib, pkgs, ... }:

{

  nixpkgs.overlays = [
    (import (builtins.fetchTarball
      "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz"))
  ];

  home.packages = with pkgs; [

    emacs-git

    nerdfonts
    ripgrep
    fd
    coreutils
    direnv
    clang
    ispell
    pandoc
    nodejs_22
    libvterm
    cargo
    cmake
    gnumake
    libtool
  ];
}
