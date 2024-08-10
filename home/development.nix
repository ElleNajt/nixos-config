{ config, lib, pkgs, ... }:

{
  imports = [
    ./development/nix.nix
    ./development/python.nix
    ./development/rust.nix
    ./development/elisp.nix
    ./development/shell.nix
  ];

}
