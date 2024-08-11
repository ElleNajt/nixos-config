{ config, lib, pkgs, ... }:

{

  nixpkgs.overlays = [
    (import (builtins.fetchTarball
      "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz"))
  ];

  home.packages = with pkgs; [

    (pkgs.texlive.combine {
      inherit (pkgs.texlive)
        capt-of collection-fontsrecommended dvipng fancyvrb float fncychap
        framed mathpartir needspace parskip scheme-basic semantic tabulary
        titlesec ulem upquote varwidth wrapfig bussproofs bussproofs-extra;
    })

    (makeDesktopItem {
      name = "Doom Emacs";
      desktopName = "Doom Emacs";
      icon = "emacs";
      exec = "${emacs-git}/bin/emacs";
    })

    (makeDesktopItem {
      name = "Doom Emacs (Debug Mode)";
      desktopName = "Doom Emacs (Debug Mode)";
      icon = "emacs";
      exec = "${emacs-git}/bin/emacs --debug-init";
    })

    emacs-git
    emacsPackages.treesit-grammars.with-all-grammars
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
    imagemagick

    # Stolen from aspen
    (writeShellApplication {
      name = "edit-input";

      runtimeInputs = [ xdotool xclip ];
      text = ''
        set -euo pipefail

        sleep 0.2
        xdotool key ctrl+a ctrl+c
        xclip -out -selection clipboard > /tmp/EDIT
        emacsclient -c /tmp/EDIT
        xclip -in -selection clipboard < /tmp/EDIT
        sleep 0.2
        xdotool key ctrl+v
        rm /tmp/EDIT
      '';
    })
  ];

}
