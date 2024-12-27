{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [

    thefuck
    shfmt
    shellcheck
    jq
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
    nix-direnv.enable = true;
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
      "ytd" = "yt-dlp -P /mnt/shared/videos";
    };

  };

  # taken from this
  # https://github.com/direnv/direnv/issues/73
  # this makes it possible for envrc to set aliases

  home.file.".direnvrc".text = ''
    # Clear existing aliases when entering a directory
    rm -rf "$PWD/.envrc-aliases"

    export_alias() {
        local name=$1
        shift

        local alias_dir="$PWD/.envrc-aliases"
        local alias_file="$alias_dir/$name"
        local oldpath="$PATH"

        if ! [[ ":$PATH:" == /":$alias_dir:"/ ]]; then
            mkdir -p "$alias_dir"
            PATH_add "$alias_dir"
        fi

        cat <<EOT >$alias_file
    #!/usr/bin/env bash
    set -e
    PATH="$oldpath"
    exec $@
    EOT
        chmod +x "$alias_file"
    }
  '';

}
