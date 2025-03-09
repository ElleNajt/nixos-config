{ config, lib, pkgs, ... }:

{

  imports = [
    ./home/i3.nix
    ./home/emacs.nix
    ./home/email.nix
    ./home/development.nix
    ./home/vms.nix
    ./home/display.nix
    ./home/computers/etude.nix
  ];

  config = {

    home.username = "elle";
    home.homeDirectory = "/home/elle";

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    home.stateVersion = "24.05"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.

    home.packages = with pkgs; [
      firefox
      alacritty
      # beeper
      file
      psmisc
      wget
      yt-dlp
      ffmpeg

      # nix stuff
      niv
      nix-search-cli

      xorg.xev
      xorg.libxcvt

      xlayoutdisplay
      arandr

      #silly stuff
      cowsay
      fortune
      cmatrix
      oneko
      pipes

      # steam

      xdotool
      # # You can also create simple shell scripts directly inside your
      # # configuration. For example, this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')
    ];

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    home.file = {
      # # Building this configuration will create a copy of 'dotfiles/screenrc' in
      # # the Nix store. Activating the configuration will then make '~/.screenrc' a
      # # symlink to the Nix store copy.
      # ".screenrc".source = dotfiles/screenrc;

      # # You can also set the file content immediately.
      # ".gradle/gradle.properties".text = ''
      #   org.gradle.console=verbose
      #   org.gradle.daemon.idletimeout=3600000
      # '';
    };

    # Home Manager can also manage your environment variables through
    # 'home.sessionVariables'. These will be explicitly sourced when using a
    # shell provided by Home Manager. If you don't want to manage your shell
    # through Home Manager then you have to manually source 'hm-session-vars.sh'
    # located at either
    #
    #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    #
    # or
    #
    #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
    #
    # or
    #
    #  /etc/profiles/per-user/elle/etc/profile.d/hm-session-vars.sh
    #

    home.sessionVariables = {
      EDITOR = "emacsclient";
      PASSWORD_STORE_DIR = "/home/elle/.local/share/password-store";
    };

    home.sessionPath = [ "/home/elle/.emacs.d/bin" "/home/elle/.doom.d/bin" ];

    # different parts of emacs keep looking for it in ~/.password-store/ , so I'm symlinking it there
    home.file.".password-store".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.local/share/password-store";

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
    programs.password-store.enable = true;

    programs.gpg.enable = true;
    services.gpg-agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
      enableZshIntegration = true;
      extraConfig = ''
        allow-emacs-pinentry
      '';
    };

    home.sessionVariables.NIX_PATH =
      "nixpkgs=${(import ./nix/sources.nix).nixpkgs}";
  };
}
