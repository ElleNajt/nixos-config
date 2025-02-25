{ ... }:

let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { config = { allowUnfree = true; }; };
  home-manager = import sources.home-manager { };

in rec {
  nixos = pkgs.nixos ({ ... }: { imports = [ ./configuration.nix ]; });
  system = nixos.config.system.build.toplevel;

  home = ((import (home-manager.path + "/modules")) {
    inherit pkgs;
    configuration = { ... }: { imports = [ ./home.nix ]; };
  }).activation-script;
}
