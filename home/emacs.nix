{ config, lib, pkgs, ... }:

let sources = import ./../nix/sources.nix;

in {

  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = sources.emacs-overlay.url;
      sha256 = sources.emacs-overlay.sha256;
    }))
  ];

  home.packages = with pkgs; [

    # emacs-git
    emacs

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
    # cargo
    cmake
    gnumake
    libtool
    imagemagick

    # (pkgs.texlive.combine {
    #   inherit (pkgs.texlive)
    #     capt-of collection-fontsrecommended dvipng fancyvrb float fncychap
    #     framed mathpartir needspace parskip scheme-basic semantic tabulary
    #     titlesec ulem upquote varwidth wrapfig bussproofs bussproofs-extra;
    # })

    (makeDesktopItem {
      name = "SIGUSR2 Doom";
      desktopName = "SIGUSR2 Doom";
      icon = "emacs";
      exec = "kitty ${
          pkgs.writeShellScript "doom-pkill-sigusr2" ''
            pkill -SIGUSR2 emacs
          ''
        }";
    })

    (makeDesktopItem {
      name = "Upgrade Doom";
      desktopName = "Upgrade Doom";
      icon = "emacs";
      exec = "kitty ${
          pkgs.writeShellScript "doom-sync" ''
            if ! /home/elle/.emacs.d/bin/doom upgrade; then
              echo 'Doom sync failed'
              exec bash
            fi
          ''
        }";
    })

    (makeDesktopItem {
      name = "Sync Doom";
      desktopName = "Sync Doom";
      icon = "emacs";
      exec = "kitty ${
          pkgs.writeShellScript "doom-sync" ''
            if ! /home/elle/.emacs.d/bin/doom sync; then
              echo 'Doom sync failed'
              exec bash
            fi
          ''
        }";
    })

    (makeDesktopItem {
      name = "Doom Emacs";
      desktopName = "Doom Emacs";
      icon = "emacs";
      exec = "${emacs}/bin/emacs";
    })

    (makeDesktopItem {
      name = "Doom Emacs (Debug Mode)";
      desktopName = "Doom Emacs (Debug Mode)";
      icon = "emacs";
      exec = "${emacs}/bin/emacs --debug-init";
    })

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
