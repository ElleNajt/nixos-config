{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    clojure
    leiningen
    supercollider
    jack2
    jre
    cljfmt

    clojure-lsp
    clj-kondo
    zprint
    # parinfer-rust-emacs
    parinfer-rust
  ];

  home.file.".zprintrc".text = ''
    {:width 60}
  '';

}
