{ config, lib, pkgs, ... }:
with lib; {
  options = { elle.is_vm = mkEnableOption "is_vm"; };

  config = mkIf config.elle.is_vm {

    home.packages = [ pkgs.spice-vdagent ];

    systemd.user.services.spice-vdagent = {
      Unit = {
        Description = "Spice guest agent";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
        Restart = "always";
        RestartSec = 10;
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };

    systemd.user.services.spice-vdagentd = {
      Unit = {
        Description = "Spice guest agent daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagentd -x";
        Restart = "always";
        RestartSec = 10;
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };

  };
}
