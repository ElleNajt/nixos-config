{ config, lib, pkgs, ... }:
let

  py3status = pkgs.python3Packages.py3status.overridePythonAttrs (old: rec {
    name = "${pname}-${old.version}";
    pname = "py3status-glittershark";
    src = pkgs.fetchFromGitHub {
      owner = "glittershark";
      repo = "py3status";
      rev = "f243be1458cdabd5a7524adb76b5db99006c810c";
      sha256 = "0ffmv91562yk0wigriw4d5nfg2b32wqx8x78qvdqkawzvgbwrwvl";
    };
  });

  solarized = import ./common/solarized.nix;

  colors = {
    focused = {
      border = "#4c7899";
      background = "#285577";
      text = "#ffffff";
      indicator = "#2e9ef4";
      childBorder = "#285577";
    };
    focusedInactive = {
      border = "#333333";
      background = "#5f676a";
      text = "#ffffff";
      indicator = "#484e50";
      childBorder = "#5f676a";
    };
    unfocused = {
      border = "#333333";
      background = "#222222";
      text = "#888888";
      indicator = "#292d2e";
      childBorder = "#222222";
    };
    urgent = {
      border = "#2f343a";
      background = "#900000";
      text = "#ffffff";
      indicator = "#900000";
      childBorder = "#900000";
    };
    placeholder = {
      border = "#000000";
      background = "#0c0c0c";
      text = "#ffffff";
      indicator = "#000000";
      childBorder = "#0c0c0c";
    };
    background = "#ffffff";
  };
  mod = "Mod4+Mod1";

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

    # order += "external_script current_task"
    order += "read_file emacs_task"
    order += "cpu_usage"
    order += "time"

    cpu_usage {
        format = "CPU: %usage"
    }

    read_file emacs_task {
              format = "Current Task: %content"
              path = "/home/elle/.emacs.d/current-task"
    }

    load {
        format = "%5min"
    }

    time {
        format = " %a %h %d  %I:%M "
    }

    external_script current_task {
        script_path = '${
          emacsclient "(elle/org-current-clocked-in-task-message)"
        }'
        format = 'Task: {output}'
        cache_timeout = 60
        color = "#93a1a1"
    }

    tztime utc {
        timezone = "UTC"
        format = "    %H·%M    "
    }

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
      dconf

      # Screenshots
      maim
      xclip

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
            }) (range 1 9)) ++ [(rec {
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
              "${mod}+p" =
                "exec rofi-pass --root '/home/elle/.local/share/password-store/' -font '${decorationFont}'";

              # Edit current buffer
              "${mod}+v" = "exec edit-input";

              # Scratch buffer
              "${mod}+minus" = "scratchpad show";
              "${mod}+Shift+minus" = "move scratchpad";
              # "${mod}+space" = "focus mode_toggle";

              # this is how you make something not a scratch pad
              # "${mod}+Shift+space" = "floating toggle";

              # Screen Layout
              "${mod}+Shift+t" = "exec xrandr --auto";

              # Notifications
              "${mod}+Shift+n" = "exec killall -SIGUSR1 .dunst-wrapped";
              "${mod}+n" = "exec killall -SIGUSR2 .dunst-wrapped";
              "${mod}+space" = "exec ${pkgs.dunst}/bin/dunstctl close";
              "${mod}+Shift+space" =
                "exec ${pkgs.dunst}/bin/dunstctl close-all";
              "${mod}+grave" = "exec ${pkgs.dunst}/bin/dunstctl history-pop";
              "${mod}+period" = "exec ${pkgs.dunst}/bin/dunstctl action";
            })]);

        inherit fonts colors;

        modes.resize = {
          l = "resize shrink width 5 px or 5 ppt";
          k = "resize grow height 5 px or 5 ppt";
          j = "resize shrink height 5 px or 5 ppt";
          h = "resize grow width 5 px or 5 ppt";

          Return = ''mode "default"'';
        };

        bars = [{
          statusCommand = "${py3status}/bin/py3status -c ${i3status-conf}";
          inherit fonts;
          colors = {
            background = "#000000";
            statusline = "#ffffff";
            separator = "#666666";
            focusedWorkspace = {
              border = "#4c7899";
              background = "#285577";
              text = "#ffffff";
            };
            activeWorkspace = {
              border = "#333333";
              background = "#5f676a";
              text = "#ffffff";
            };
            inactiveWorkspace = {
              border = "#333333";
              background = "#222222";
              text = "#888888";
            };
            urgentWorkspace = {
              border = "#2f343a";
              background = "#900000";
              text = "#ffffff";
            };
            bindingMode = {
              border = "#2f343a";
              background = "#900000";
              text = "#ffffff";
            };
          };
          position = "top";
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
