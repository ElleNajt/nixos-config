{ config, lib, pkgs, ... }:

with lib; {

  options = { elle.is_vm = mkEnableOption "is_vm"; };

  config = mkIf config.elle.is_vm {
    services.spice-webdavd.enable = true;
    services.spice-vdagentd.enable = true;
    services.qemuGuest.enable = true;
    environment.sessionVariables = { "LIBGL_ALWAYS_SOFTWARE" = "true"; };
  };
}
