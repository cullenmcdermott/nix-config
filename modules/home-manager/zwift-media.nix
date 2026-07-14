{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.zwift-media;

  # macOS routes these consumer key codes (same events as the keyboard's
  # F7/F8/F9 media keys) to the system "Now Playing" session, which browsers
  # register with via the MediaSession API. No focus stealing, no browser
  # detection — works while Zwift is fullscreen.
  zwiftCondition = lib.optionals cfg.enableZwiftCondition [
    {
      type = "frontmost_application_if";
      file_paths = [
        "Zwift/ZwiftAppSilicon$"
      ];
    }
  ];

  mkRule = description: button: to: {
    inherit description;
    manipulators = [
      {
        type = "basic";
        from = {
          pointing_button = button;
        };
        to = [ to ];
        conditions = zwiftCondition;
      }
    ];
  };

  # Seek by injecting JavaScript into Arc's active tab via AppleScript.
  # Media keys can't seek (YouTube only exposes next/prev track to the
  # system media session), and this doesn't steal focus from Zwift.
  # The IIFE avoids polluting the page's global scope, and backticks
  # avoid a third level of quote nesting. Requires Automation permission
  # for karabiner_console_user_server -> Arc.
  seekCommand =
    offset:
    "osascript -e 'tell application \"Arc\" to tell front window to execute active tab javascript \"(function(){var v=document.getElementsByTagName(`video`)[0]; if(v){v.currentTime+=${offset}}})()\"'";

  # Button codes are for the current controllers (Xbox layout / 8BitDo).
  # Use Karabiner-EventViewer to find codes for other controllers.
  karabinerConfig = {
    title = "Game Controller Media Controls";
    rules = [
      (mkRule "Controller: A Button = Play/Pause" "button1" {
        consumer_key_code = "play_or_pause";
      })
      (mkRule "Controller: Y Button = Seek Forward ${toString cfg.seekForwardSeconds}s" "button8" {
        shell_command = seekCommand (toString cfg.seekForwardSeconds);
      })
      (mkRule "Controller: X Button = Seek Back ${toString cfg.seekBackSeconds}s" "button7" {
        shell_command = seekCommand "-${toString cfg.seekBackSeconds}";
      })
      (mkRule "Controller: B Button = Mute" "button2" {
        consumer_key_code = "mute";
      })
    ];
  };
in
{
  options.programs.zwift-media = {
    enable = lib.mkEnableOption "game controller media keys for browser playback during Zwift";

    seekForwardSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Seconds to seek forward per Y-button press (sized for skipping sponsor segments).";
    };

    seekBackSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Seconds to seek back per X-button press.";
    };

    enableZwiftCondition = lib.mkOption {
      type = lib.types.bool;
      default = true; # Only trigger when Zwift is frontmost
      description = ''
        If true, media controls only work when Zwift is the frontmost application.
        If false, controls work globally.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # NOTE: Karabiner-Elements must be installed via Homebrew cask, not nixpkgs,
    # because it requires privileged system daemons that can't be sandboxed.
    # The homebrew cask is added in modules/darwin/homebrew-personal.nix
    #
    # Karabiner copies rules into karabiner.json when they are enabled, so after
    # changing this file: Karabiner-Elements > Complex Modifications > remove the
    # old rules and re-add "Game Controller Media Controls".
    xdg.configFile."karabiner/assets/complex_modifications/zwift-media.json" = {
      text = builtins.toJSON karabinerConfig;
    };
  };
}
