{ config, lib, pkgs, ... }:
with lib; {

  home.packages = [ pkgs.spice-vdagent ];
  systemd.user.services.spice-vdagent = mkIf config.elle.is_vm {
    Unit = {
      Description = "Spice vdagent";
      After = [ "display-manager.service" "spice-vdagentd.service" ];
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
    Service = {
      Type = "forking";
      ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
