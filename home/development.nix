{ config, lib, pkgs, ... }:

{
  imports = [
    ./development/nix.nix
    ./development/python.nix
    ./development/clojure.nix
    # ./development/rust.nix
    ./development/elisp.nix
    ./development/c.nix
    ./development/shell.nix
    ./development/latex.nix
  ];

  home.packages = with pkgs; [
    mdbook
    gh
    libnotify
    autoconf
    automake
    libtool
    m4
  ];
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    userEmail = "lnajt4@gmail.com";
    userName = "Elle Najt";
    ignores = [
      "*.sw*"
      ".classpath"
      ".project"
      ".settings/"
      ".stack-work-profiling"
      ".projectile"
    ];
    extraConfig = {
      merge.conflictstyle = "diff3";
      rerere.enabled = "true";
      advice.skippedCherryPicks = "false";
    };

    delta = {
      enable = true;
      options = {
        syntax-theme = "Solarized (light)";
        hunk-style = "plain";
        commit-style = "box";
      };
    };
  };

  programs.readline = {
    enable = true;
    extraConfig = ''
      set editing-mode vi
    '';
  };

}
