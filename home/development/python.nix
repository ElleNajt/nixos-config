{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    texinfo
    pkgs.python313
    pkgs.black
    pkgs.isort
    # pkgs.python313Packages.pip
    pkgs.basedpyright

    python3Packages.ipdb
    python3Packages.jupyter_core
    python3Packages.jupyterlab
    python3Packages.notebook
    python3Packages.ipykernel
  ];
}
