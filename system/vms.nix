{ config, lib, pkgs, ... }:

with lib; {

  imports = [ ./vm-display-resize.nix ];
  options = { elle.is_vm = mkEnableOption "is_vm"; };

  config = mkIf config.elle.is_vm {

    environment.systemPackages = with pkgs; [
      spice-gtk
      virtiofsd
      spice-vdagent

    ];

    environment.sessionVariables = { "LIBGL_ALWAYS_SOFTWARE" = "true"; };

    services.spice-vdagentd.enable = true;
    services.spice-webdavd.enable = true;
    services.qemuGuest.enable = true;

    fileSystems."/mnt/shared" = {
      device = "share";
      fsType = "9p";
      options = [
        "trans=virtio"
        "version=9p2000.L"
        "rw"
        "nofail"
        "_netdev"
        "noatime"
        "msize=1048576"
        "cache=none"
        "access=any"
        "dfltuid=${toString config.users.users.elle.uid}"
        "dfltgid=${toString config.users.groups.users.gid}"
        "uid=${toString config.users.users.elle.uid}"
        "gid=${toString config.users.groups.users.gid}"
        "dfltmode=0777"
        "mode=0777"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };

    # system.activationScripts.fixSharedPermissions = ''
    #   chmod 755 /mnt/shared
    #   chown ${config.users.users.elle.name}:${config.users.groups.users.name} /mnt/shared
    # '';
    # # TODO This solution doesn't solve the problem of new files, or files that
    # # get edited on the mac side, e.g. by syncthing.

    boot.kernelModules = [ "9p" "9pnet" "9pnet_virtio" ];
    boot.initrd.availableKernelModules =
      [ "virtio_pci" "9p" "9pnet" "9pnet_virtio" ];

  };
}
