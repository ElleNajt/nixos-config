{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    texinfo
    pkgs.python313
    # pkgs.python313Packages.pip
  ];
}
