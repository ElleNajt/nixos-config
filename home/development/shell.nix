{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [

    thefuck
    shfmt
    shellcheck
  ];

  programs.thefuck.enable = true;
  programs.thefuck.enableBashIntegration = true;
  programs.thefuck.enableZshIntegration = true;
  programs.kitty.extraConfig = "confirm_os_window_close -1";

  programs.kitty.enable = true;

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.zsh = {

    enable = true;
    shellAliases = {
      "oops" = "fuck";
      "nrs" = "sudo ~/code/nixos-config/rebuild-nixos";
      "hms" = "~/code/nixos-config/rebuild-home";
      "gc" = "git clone";
      "fixd" = " xrandr --output Virtual-1 --mode 3024x1890_75.00 --dpi 144";
    };

  };
}
