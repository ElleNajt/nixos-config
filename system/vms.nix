{ config, lib, pkgs, ... }:

with lib; {

  imports = [ ./vm-display-resize.nix ];
  options = { elle.is_vm = mkEnableOption "is_vm"; };

  config = mkIf config.elle.is_vm {

    environment.systemPackages = with pkgs; [ spice-gtk ];

    services.davfs2.enable = true;

    environment.sessionVariables = { "LIBGL_ALWAYS_SOFTWARE" = "true"; };

    fileSystems."/mnt/shared" = {
      device = "http://127.0.0.1:9843";
      fsType = "davfs";
      options =
        [ "rw" "uid=elle" "gid=users" "noexec" "netsec" "x-systemd.automount" ];
    };

    services.spice-vdagentd.enable = true;
    services.spice-webdavd.enable = true;
    services.qemuGuest.enable = true;
  };
}
