{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    texinfo
    # pkgs.python313
    pkgs.black
    pkgs.isort
    # pkgs.python313Packages.pip
    pkgs.basedpyright
    zeromq

    (python311.withPackages (ps:
      with ps; [
        ipdb
        ipykernel
        jupyter
        notebook
        jupyter_core
        jupyterlab
        pyzmq
        pandas
        tabulate
        flake8

      ]))

  ];
}
