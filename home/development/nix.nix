{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [ nil nixfmt-classic ];
}
