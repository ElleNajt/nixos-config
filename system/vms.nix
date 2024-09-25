{ config, lib, pkgs, ... }:

with lib; {

  imports = [ ./vm-display-resize.nix ];
  options = { elle.is_vm = mkEnableOption "is_vm"; };

  config = mkIf config.elle.is_vm {

    environment.systemPackages = with pkgs; [
      spice-gtk
      virtiofsd

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
        "noatime"
        "msize=1048576"
        "cache=loose"
        "access=any"
        # "uid=${toString config.users.users.elle.uid}"
        # "gid=${toString config.users.groups.users.gid}"
        # "fmode=0644"
        # "dmode=0755"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };

    # Ensure we have 9P support
    boot.kernelModules = [ "9p" "9pnet" "9pnet_virtio" ];
    boot.initrd.availableKernelModules =
      [ "virtio_pci" "9p" "9pnet" "9pnet_virtio" ];

  };
}
