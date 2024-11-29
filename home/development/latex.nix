{ config, pkgs, ... }:

let
  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium dvisvgm dvipng # for preview and export as html
      wrapfig amsmath ulem hyperref capt-of parskip;
  });
in {
  home.packages = with pkgs; [ tex ];

  # programs.bash = {
  #   enable = true;
  #   initExtra = ''
  #     export PATH=$PATH:${pkgs.texlive.combined.scheme-medium}/bin
  #   '';
  # };

  # programs.zsh = {
  #   enable = true;
  #   initExtra = ''
  #     export PATH=$PATH:${pkgs.texlive.combined.scheme-medium}/bin
  #   '';
  # };

}
