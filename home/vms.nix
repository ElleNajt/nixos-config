{ config, lib, pkgs, ... }:
with lib; {

  options = { elle.is_vm = mkEnableOption "is_vm"; };

  config = mkIf config.elle.is_vm {
    home.packages = with pkgs; [ spice-gtk spice-vdagent davfs2 ];
  };
}
