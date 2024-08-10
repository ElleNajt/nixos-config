{ config, lib, pkgs, ... }:
let

  solarized = import ./common/solarized.nix;

  mod = "Mod4+Mod1";

  # TODO pull this out into lib
  emacsclient = eval:
    pkgs.writeShellScript "emacsclient-eval" ''
      msg=$(emacsclient --eval '${eval}' 2>&1)
      echo "''${msg:1:-1}"
    '';

  i3status-conf = pkgs.writeText "i3status.conf" ''
    general {
        output_format = i3bar
        colors = true
        color_good = "#859900"

        interval = 1
    }

    order += "external_script current_task"
    order += "external_script inbox"
    order += "volume_status"
    order += "wireless ${config.system.machine.wirelessInterface}"
    # order += "ethernet enp3s0f0"
    order += "cpu_usage"
    ${lib.optionalString (!isNull config.system.machine.battery) ''
      order += "battery ${toString config.system.machine.battery}"
    ''}
    # order += "volume master"
    order += "time"
    order += "tztime utc"


    battery ${toString config.system.machine.battery} {
        format = "%status %percentage (%remaining)"
        path = "/sys/class/power_supply/BAT%d/uevent"
        low_threshold = 10
    }

    cpu_usage {
        format = "CPU: %usage"
    }

    load {
        format = "%5min"
    }

    time {
        format = "    %a %h %d ⌚   %I:%M     "
    }


    external_script inbox {
        script_path = '${emacsclient "(aspen/num-inbox-items-message)"}'
        format = 'Inbox: {output}'
        cache_timeout = 120
        color = "#93a1a1"
    }

    external_script current_task {
        script_path = '${
          emacsclient "(aspen/org-current-clocked-in-task-message)"
        }'
        # format = '{output}'
        cache_timeout = 60
        color = "#93a1a1"
    }

    tztime utc {
        timezone = "UTC"
        format = "    %H·%M    "
    }

  '';

  i3status-command = pkgs.writeShellScript "i3status.sh" ''
    py3status -c /tmp/i3status.conf
  '';

  inherit (builtins) map;
  inherit (lib) mkMerge range;
in {
  options = with lib; {
    system.machine = {
      wirelessInterface = mkOption {
        description = ''
          Name of the primary wireless interface. Used by i3status, etc.
        '';
        default = "wlp3s0";
        type = types.str;
      };

      i3FontSize = mkOption {
        description = "Font size to use in i3 window decorations etc.";
        default = 16;
        type = types.int;
      };

      battery = mkOption {
        description = "Battery index for this system's battery";
        default = 0;
        type = types.nullOr types.int;
      };
    };
  };

  config = let
    fontName = "MesloLGSDZ";
    fontSize = config.system.machine.i3FontSize;
    fonts = {
      names = [ fontName ];
      size = fontSize * 1.0;
    };
    decorationFont = "${fontName} ${toString fontSize}";
  in {
    home.packages = with pkgs; [
      rofi
      rofi-pass
      i3lock
      i3status
      dconf # for gtk

      # Screenshots
      maim

      # GIFs
      picom
      peek

      (pkgs.writeShellScriptBin "lock" ''
        playerctl pause
        ${pkgs.i3lock}/bin/i3lock -c 222222
      '')
    ];

    xsession.scriptPath = ".xsession";

    xsession.windowManager.i3 = {
      enable = true;
      config = {
        keybindings =

          mkMerge (

            (map (n: {
              "${mod}+${toString n}" = "workspace ${toString n}";
              "${mod}+Shift+${toString n}" =
                "move container to workspace ${toString n}";
            }) (range 0 9)) ++ [(rec {
              "${mod}+h" = "focus left";
              "${mod}+j" = "focus down";
              "${mod}+k" = "focus up";
              "${mod}+l" = "focus right";
              "${mod}+semicolon" = "focus parent";

              "${mod}+Shift+h" = "move left";
              "${mod}+Shift+j" = "move down";
              "${mod}+Shift+k" = "move up";
              "${mod}+Shift+l" = "move right";

              "${mod}+Shift+x" = "kill";

              "${mod}+Return" = "exec kitty";

              "${mod}+Shift+s" = "split h";
              "${mod}+Shift+v" = "split v";
              "${mod}+e" = "layout toggle split";
              "${mod}+w" = "layout tabbed";
              "${mod}+s" = "layout stacking";

              "${mod}+f" = "fullscreen";

              "${mod}+Shift+r" = "restart";

              "${mod}+r" = "mode resize";

              # Marks
              "${mod}+Shift+m" =
                ''exec i3-input -F "mark %s" -l 1 -P 'Mark: ' '';
              "${mod}+m" =
                ''exec i3-input -F '[con_mark="%s"] focus' -l 1 -P 'Go to: ' '';

              # Screenshots
              "${mod}+q" =
                ''exec "maim -s | xclip -selection clipboard -t image/png"'';
              "${mod}+Ctrl+q" = "exec ${
                  pkgs.writeShellScript "peek.sh" ''
                    ${pkgs.picom}/bin/picom &
                    picom_pid=$!
                    ${pkgs.peek}/bin/peek || true
                    kill -SIGINT $picom_pid
                  ''
                }";

              # Launching applications
              "${mod}+u" = "exec ${
                  pkgs.writeShellScript "rofi" ''
                    rofi \
                      -modi 'combi' \
                      -combi-modi "window,drun,ssh,run" \
                      -font '${decorationFont}' \
                      -show combi
                  ''
                }";

              # Passwords
              "${mod}+p" = "exec rofi-pass -font '${decorationFont}'";

              # Edit current buffer
              "${mod}+v" = "exec edit-input";

              # Media
              "XF86AudioRaiseVolume" = "exec pulseaudio-ctl up";
              "XF86AudioLowerVolume" = "exec pulseaudio-ctl down";
              "XF86AudioMute" = "exec pulseaudio-ctl mute";

              # Lock
              Pause = "exec lock";

              # Brightness
              "XF86MonBrightnessDown" =
                "exec ${pkgs.brightnessctl}/bin/brightnessctl -q s 5%-";
              "XF86MonBrightnessUp" =
                "exec ${pkgs.brightnessctl}/bin/brightnessctl -q s 5%+";

              # Scratch buffer
              "${mod}+minus" = "scratchpad show";
              "${mod}+Shift+minus" = "move scratchpad";
              "${mod}+space" = "focus mode_toggle";
              "${mod}+Shift+space" = "floating toggle";

              # Screen Layout
              "${mod}+Shift+t" = "exec xrandr --auto";

              # Notifications
              "${mod}+Shift+n" = "exec killall -SIGUSR1 .dunst-wrapped";
              "${mod}+n" = "exec killall -SIGUSR2 .dunst-wrapped";
              "Control+space" = "exec ${pkgs.dunst}/bin/dunstctl close";
              "Control+Shift+space" =
                "exec ${pkgs.dunst}/bin/dunstctl close-all";
              "Control+grave" = "exec ${pkgs.dunst}/bin/dunstctl history-pop";
              "Control+Shift+period" = "exec ${pkgs.dunst}/bin/dunstctl action";
            })]);

        inherit fonts;

        colors = with solarized; rec {
          focused = {
            border = base01;
            background = base01;
            text = base3;
            indicator = red;
            childBorder = base02;
          };
          focusedInactive = focused // {
            border = base03;
            background = base03;
            # text = base1;
          };
          unfocused = focusedInactive;
          background = base03;
        };

        modes.resize = {
          l = "resize shrink width 5 px or 5 ppt";
          k = "resize grow height 5 px or 5 ppt";
          j = "resize shrink height 5 px or 5 ppt";
          h = "resize grow width 5 px or 5 ppt";

          Return = ''mode "default"'';
        };

        bars = [{
          statusCommand = "${i3status-command}";
          inherit fonts;
          position = "top";
          colors = with solarized; rec {
            background = base03;
            statusline = base3;
            separator = base1;
            activeWorkspace = {
              border = base03;
              background = base1;
              text = base3;
            };
            focusedWorkspace = activeWorkspace;
            inactiveWorkspace = activeWorkspace // { background = base01; };
            urgentWorkspace = activeWorkspace // { background = red; };
          };
        }];

        window.titlebar = true;
      };
    };

    services.dunst = {
      enable = true;
      settings = with solarized; {
        global = {
          font =
            "MesloLGSDZ ${toString (config.system.machine.i3FontSize * 1.5)}";
          allow_markup = true;
          format = ''
            <b>%s</b>
            %b'';
          sort = true;
          alignment = "left";
          geometry = "600x15-40+40";
          idle_threshold = 120;
          separator_color = "frame";
          separator_height = 1;
          word_wrap = true;
          padding = 8;
          horizontal_padding = 8;
          max_icon_size = 45;
        };

        frame = {
          width = 0;
          color = "#aaaaaa";
        };

        urgency_low = {
          background = base03;
          foreground = base3;
          timeout = 5;
        };

        urgency_normal = {
          background = base02;
          foreground = base3;
          timeout = 7;
        };

        urgency_critical = {
          background = red;
          foreground = base3;
          timeout = 0;
        };
      };
    };

    gtk = {
      enable = true;
      iconTheme.name = "Adwaita";
      theme.name = "Adwaita";
    };
  };
}
