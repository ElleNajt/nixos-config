{ config, lib, pkgs, ... }:

let
  add-xrandr-modes-script = pkgs.writeShellScript "add-xrandr-modes" ''
    add_mode_if_not_exists() {
            mode_name="$1"
            mode_params="$2"
            output="$3"
            if ! ${pkgs.xorg.xrandr}/bin/xrandr --query | grep "$mode_name" > /dev/null; then
              ${pkgs.xorg.xrandr}/bin/xrandr --newmode $mode_name $mode_params
              ${pkgs.xorg.xrandr}/bin/xrandr --addmode $output $mode_name
            fi
          }
    add_mode_if_not_exists "3024x1890_75.00" "620.75 3024 3280 3608 4192 1890 1893 1899 1975 -hsync +vsync" "Virtual-1"
    add_mode_if_not_exists "3840x2160_75.00" "620.75 3024 3280 3608 4192 1890 1893 1899 1975 -hsync +vsync" "Virtual-1"
  '';

  set-default-resolution-at-startup-script =
    pkgs.writeShellScript "set-default-resolution" ''

      ## TODO : Do this based on the plugged in monitor.
      xrandr --output Virtual-1 --mode 3024x1890_75.00 --dpi 144

    '';
in {

  imports = [ ../platforms/linux.nix ];

  elle.is_vm = true;

  systemd.user.services.create_xrandr_modes = {
    Unit = {
      Description = "create xrandr modes";
      After = [ "display-manager.service" "graphical.target" ];
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
    Service = {
      Type = "oneshot";
      # with oneshot, dependencies start after it has succeeded.
      ExecStart = "${add-xrandr-modes-script}";
      Restart = "on-failure";
      RestartSec = "5s";
    };

  };

  systemd.user.services.set_default_resolution_at_startup = {
    Unit = {
      Description = "set default resolution";
      After =
        [ "display-manager.service" "graphical.target" "create_xrandr_modes" ];
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
    Service = {
      Type = "oneshot";
      ExecStart = "${set-default-resolution-at-startup-script}";
      Restart = "on-failure";
      RestartSec = "5s";
    };

  };

}
