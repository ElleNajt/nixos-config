{ config, lib, pkgs, ... }:
with lib; {
  options = { elle.is_vm = mkEnableOption "is_vm"; };

  imports = [ ./spice.nix ];

}
