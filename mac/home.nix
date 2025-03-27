{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "elle";
  home.homeDirectory = "/Users/elle";

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

  black
  direnv
  ffmpeg
  gh
  imagemagick
  ispell
  nix-direnv
  pandoc
  parallel
  parinfer-rust
  pass
  pngpaste
  pyright
  python3
  ripgrep
  rlwrap
  ruff
  samba
  shellcheck
  shfmt
  tree
  vim
  w3m
  yt-dlp

  clojure
  babashka
  leiningen
  jre
  cljfmt

  clojure-lsp
  clj-kondo
  zprint
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

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

    ".overtone/config.clj".text = ''

    {:os :mac,
    :user-name "Elle",
    :server :internal,
    :sc-args {:hw-sample-rate 44100},
    :versions-seen #{"v0.16.3331" "v0.10.6"}}
    '';

    ".bashrc".text = ''
      set -o vi
      PATH="$PATH:~/scripts"
      alias ipython="nix-shell -p 'python3.withPackages(p:[p.ipython p.pandas])' --run ipython"
      . "$HOME/.cargo/env"
      export PASSWORD_STORE_DIR="~/.local/share/password-store"
      alias hms="home-manager switch"

      alias brewup="brew bundle --global";
    '';

    ".zshrc".text = ''
      set -o vi
      eval "$(direnv hook zsh)"

      PATH="$PATH:~/scripts"
      PATH="/Library/TeX/texbin:$PATH"

      export PASSWORD_STORE_DIR="/Users/elle/.local/share/password-store"
      EDITOR="emacsclient"

      alias hms="home-manager switch"

      alias brewup="brew bundle --global";
      '';


    ".Brewfile".text = ''
      # Taps
      tap "d12frosted/emacs-plus"
      tap "homebrew/cask-versions"
      tap "homebrew/services"
      tap "koekeishiya/formulae"
      tap "railwaycat/emacsmacport"

      brew "aom"
      brew "autoconf"
      brew "automake"
      brew "cmake"
      brew "coreutils"
      brew "fd"
      brew "libass"
      brew "librist"
      brew "pango"
      brew "ffmpeg"
      brew "gifsicle"
      brew "git"
      brew "pkgconf"
      brew "jack", restart_service: :changed
      brew "latexindent"
      brew "libgccjit"
      brew "libtool"
      brew "m-cli"
      brew "tree-sitter"
      brew "neovim"
      brew "openjdk@21"
      brew "openvino"
      brew "poppler"
      brew "ripgrep"
      brew "showkey"
      brew "texinfo"
      brew "koekeishiya/formulae/skhd"
      brew "koekeishiya/formulae/yabai"

      cask "blackhole-2ch"
      cask "emacs"
      cask "gstreamer-runtime"
      cask "mactex"
      cask "shortcat"
      cask "supercollider"
      cask "wine-stable"
    '';

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
    EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
