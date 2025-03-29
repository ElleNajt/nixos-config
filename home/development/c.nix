{ config, lib, pkgs, ... }:

{

  home.packages = with pkgs; [
    lldb
    clang-tools
    # gcc # conflicts with clang
  ];
}
