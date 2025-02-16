{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [ nixd nil nixfmt-classic ];
}
