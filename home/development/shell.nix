{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [

    shfmt
    shellcheck
  ];

  programs.thefuck.enable = true;
  programs.thefuck.enableBashIntegration = true;
  programs.thefuck.enableZshIntegration = true;
}
