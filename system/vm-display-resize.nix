{ config, pkgs, ... }:

let
  username = "elle";
  # would be nice to make this independent of user name

  # There's a more complex script here: https://github.com/utmapp/UTM/issues/4064
  # which is appropriate if the display isn't called Virtual-1
  auto-resize-script = pkgs.writeShellScript "auto-resize-display" ''
    export DISPLAY=:0
    export XAUTHORITY=/home/${username}/.Xauthority
    call_xrandr() {
      ${pkgs.xorg.xrandr}/bin/xrandr | grep 'Virtual-1'
    }
    # FOR SOME REASON xrandr needs to be called for the below to work
    # Why?
    current_res=$(call_xrandr)


    ${pkgs.xorg.xrandr}/bin/xrandr --output Virtual-1 --auto
    res_after = $(${pkgs.xorg.xrandr}/bin/xrandr)

    echo "Display resized at $(date)" >> /tmp/display-resize.log
    echo "$current_res to $res_after" >> /tmp/display-resize.log
    echo "done!" >> /tmp/display-resize.log
  '';
in {

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", RUN+="${auto-resize-script}"
  '';

  services.udev.path = with pkgs; [ bash xorg.xrandr ];

}
