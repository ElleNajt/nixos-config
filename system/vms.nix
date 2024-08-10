{ config, lib, pkgs, ... }:

with lib; {

  imports = [ ./vm-display-resize.nix ];
  options = { elle.is_vm = mkEnableOption "is_vm"; };

  config = mkIf config.elle.is_vm {

    environment.systemPackages = with pkgs; [
      spice-gtk
      spice-vdagent
      davfs2

    ];

    services.spice-webdavd.enable = true;
    services.spice-vdagentd.enable = true;
    services.qemuGuest.enable = true;
    environment.sessionVariables = { "LIBGL_ALWAYS_SOFTWARE" = "true"; };

    # also starting them as services explicitly, since the option wasn't working
    # systemd.services.spice-vdagent = {
    #   description = "Spice guest agent";
    #   wantedBy = [ "multi-user.target" ];
    #   after = [ "display-manager.service" ];
    #   serviceConfig = {
    #     ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent";
    #     Restart = "always";
    #   };
    # };

    # systemd.services.elle-spice-vdagentd = {
    #   description = "Spice guest agent daemon";
    #   after = [ "spice-vdagentd.socket" ];
    #   serviceConfig = {
    #     ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagentd";
    #     Restart = "always";
    #   };
    # };

  };
}
