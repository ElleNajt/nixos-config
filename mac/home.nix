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


(python3.withPackages (ps: with ps; [
  ipython
  pandas
  numpy
  scipy
  matplotlib
  requests
  black
  pip
]))

  autoconf
  automake
  libtool
  pkgconf
  poppler
  libnotify
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
  ripgrep
  rlwrap
  aider-chat

  ruff
  samba
  aspell
  shellcheck

  # tidal cycles
  ghc
  cabal-install

  # haskellPackages.tidal

  haskell-language-server
  haskellPackages.ormolu
  # tidal
  # superdirt # SuperCollider plugin for Tidal

  shfmt
  gnupg
  tree
  vim
  w3m
  yt-dlp

  nodejs
  nodePackages.npm

  ] ++ (import ../home/development/Claude/containers/scripts.nix { inherit pkgs; }) ++ [

  # overtone
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

  # haskell.packages = with pkgs.haskellPackages; [ tidal ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {

    ".claude".source = ../home/development/Claude;
    ".claude".recursive = true;

    ".overtone/config.clj".text = ''

{:os :mac
 :user-name "Elle"
 :server :external
 :audio-device "Multi-Output Device"
 :sc-args {:hw-sample-rate 44100}
 :versions-seen #{"v0.16.3331" "v0.10.6"}}
    '';

    # ".ghci".text = ''
    # :set prompt "> "
    # :set -fno-print-bind-result
    # '';


    ".bashrc".text = ''
      set -o vi
      PATH="$PATH:~/scripts"
      PATH="$PATH:~/code/scripts"

      PATH="$PATH:/Users/elle/code/claude-code.el/bin"
      alias ipython="nix-shell -p 'python3.withPackages(p:[p.ipython p.pandas])' --run ipython"
      . "$HOME/.cargo/env"
      export PASSWORD_STORE_DIR="~/.local/share/password-store"
      alias hms="home-manager switch"
      alias doom="~/.emacs.d/bin/doom"

      alias brewup="brew bundle --global";
    '';

    ".zshrc".text = ''
      set -o vi
      eval "$(direnv hook zsh)"



    # NVM setup
    export NVM_DIR="$HOME/.nvm"
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

      PATH="$PATH:~/scripts"
      PATH="$PATH:~/code/scripts"
      PATH="/Library/TeX/texbin:$PATH"

      PATH="$PATH:/Users/elle/code/claude-code.el/bin"

      export PASSWORD_STORE_DIR="/Users/elle/.local/share/password-store"
      EDITOR="emacsclient"

      alias hms="home-manager switch"

      alias doom="~/.emacs.d/bin/doom"

      alias brewup="brew bundle --global";
      '';


    ".Brewfile".text = ''
      # Taps
      # tap "d12frosted/emacs-plus"
      tap "homebrew/cask-versions"
      tap "homebrew/services"
      tap "koekeishiya/formulae"
      tap "railwaycat/emacsmacport"

      brew "aom"
      # not working via brew file :(
      # brew "blackhole-2ch", require_sudo: true
      brew "autoconf"
      brew "automake"
      brew "cmake"
      brew "coreutils"
      brew "fd"
      brew "libass"
      # brew "ghc"
      # brew "cabal-install"
      # brew "haskell-stack"
      brew "cliclick"


      # brew "autoconf"
      # brew "automake"
      # brew "libtool"
      # brew "pkgconf"
      # brew "poppler"
      brew "libvterm"
      brew "librist"
      brew "pango"

      brew "nvm"
      brew "ffmpeg"
      brew "gifsicle"
      brew "git"
      brew "pkgconf"
      # brew "jack", restart_service: :changed
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
      brew "docker"

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



home.file."Library/Application Support/SuperCollider/startup.scd".text = ''
(

Server.default.options.outDevice_("SuperCollider Device");
s.reboot { // server options are only updated on reboot
    // configure the sound server: here you could add hardware specific options
    // see http://doc.sccode.org/Classes/ServerOptions.html
    s.options.numBuffers = 1024 * 256; // increase this if you need to load more samples
    s.options.memSize = 8192 * 32; // increase this if you get "alloc failed" messages
    s.options.numWireBufs = 64; // increase this if you get "exceeded number of interconnect buffers" messages
    s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
    s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
    s.options.numInputBusChannels = 2; // set this to your hardware output channel size, if necessary
    // boot the server and start SuperDirt
    s.waitForBoot {

        ~dirt = SuperDirt(2, s); // two output channels, increase if you want to pan across more channels
        ~dirt.loadSoundFiles;   // load samples (path containing a wildcard can be passed in)
        ~dirt.loadSoundFiles("/Users/Elle/Dirt/Dirt-Samples/*");
        // s.sync; // optionally: wait for samples to be read
        ~dirt.start(57120, 0 ! 12);   // start listening on port 57120, create two busses each sending audio to channel 0

        // optional, needed for convenient access from sclang:
        (
            ~d1 = ~dirt.orbits[0]; ~d2 = ~dirt.orbits[1]; ~d3 = ~dirt.orbits[2];
            ~d4 = ~dirt.orbits[3]; ~d5 = ~dirt.orbits[4]; ~d6 = ~dirt.orbits[5];
            ~d7 = ~dirt.orbits[6]; ~d8 = ~dirt.orbits[7]; ~d9 = ~dirt.orbits[8];
            ~d10 = ~dirt.orbits[9]; ~d11 = ~dirt.orbits[10]; ~d12 = ~dirt.orbits[11];
        );
    };

    s.latency = 0.3; // increase this if you get "late" messages

  // ServerOptions.devices;
  //    Server.default.options.outDevice_("SuperCollider Device");
  //    Server.default.reboot;
  //    SuperDirt.start();
};
);
'';

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
