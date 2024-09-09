{ pkgs, lib, ... }:

let
  username = "elle";
  # would be nice to make this independent of user name

  # There's a more complex script here: https://github.com/utmapp/UTM/issues/4064
  # which is appropriate if the display isn't called Virtual-1
  auto-resize-script = pkgs.writeShellScript "auto-resize-display" ''
    export PATH="${
      lib.makeBinPath (with pkgs; [ gawk xorg.xrandr gnugrep coreutils ])
    }"
    export DISPLAY=:0
    export XAUTHORITY=/home/${username}/.Xauthority

    preferred_mode=$(xrandr | grep "Virtual-1" -A1 | awk '/ +/ {print $1}' | tail -n 1)

    if [ "$preferred_mode" = "1512x945" ]; then
        xrandr --output Virtual-1 --mode 3024x1890_75.00 --dpi 144
    elif [ "$preferred_mode" = "1920x1080" ]; then
        xrandr --output Virtual-1 --mode 3840x2160_75.00 --dpi 144
    else
        ${pkgs.xorg.xrandr}/bin/xrandr --output Virtual-1 --auto
    fi

  '';
in {

  # In UTM, resize on window change needs to be on
  # check for udev-events when you change the vm window using
  # udevadm monitor --property
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", RUN+="${auto-resize-script}"
  '';

  services.udev.path = with pkgs; [ bash ];

}
