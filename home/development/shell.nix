{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [

    shfmt
    shellcheck
  ];

  programs.thefuck.enable = true;
  programs.thefuck.enableBashIntegration = true;
  programs.thefuck.enableZshIntegration = true;
  programs.kitty.extraConfig = "confirm_os_window_close -1";

  programs.kitty.enable = true;
}
