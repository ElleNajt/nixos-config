{ config, lib, pkgs, ... }:

{

  home.packages = with pkgs; [
    rustup
    cargo-edit
    cargo-expand
    cargo-udeps
    cargo-make
    cargo-bloat
    sccache
    evcxr

    # benchmarking+profiling
    cargo-criterion
    cargo-flamegraph
    coz
    inferno
    hotspot
  ];

  # programs.zsh.shellAliases = {
  #   "cg" = "cargo";
  #   "cb" = "cargo build";
  #   "ct" = "cargo test";
  #   "ctw" = "fd -e rs | entr cargo test";
  #   "cch" = "cargo check";
  # };

  # home.file.".cargo/config".text = ''
  #   [build]
  #   rustc-wrapper = "${pkgs.sccache}/bin/sccache"

  #   [target.x86_64-unknown-linux-gnu]
  #   linker = "clang"
  #   rustflags = ["-C", "link-arg=-fuse-ld=${pkgs.mold}/bin/mold"]
  # '';
}
