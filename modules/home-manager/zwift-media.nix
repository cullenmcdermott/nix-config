{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.zwift-media;

  # Configuration directory
  configDir = "${config.xdg.configHome}/zwift-media";

  # The send-to-browser script - core functionality
  sendToBrowserScript = pkgs.writeShellApplication {
    name = "zwift-media-send-to-browser";
    runtimeInputs = [ ];
    text = ''
      #!/bin/bash
      # Send a keystroke to the first running browser found
      # Usage: send-to-browser.sh <keystroke>
      # Examples:
      #   send-to-browser.sh "space"
      #   send-to-browser.sh "k"
      #   send-to-browser.sh "key code 123" (left arrow)

      set -euo pipefail

      KEYSTROKE="''${1:-}"
      if [ -z "$KEYSTROKE" ]; then
          echo "Usage: $0 <keystroke>" >&2
          exit 1
      fi

      # Read mode from config file, default to universal
      CONFIG_FILE="${configDir}/mode.conf"
      MODE="universal"
      if [ -f "$CONFIG_FILE" ]; then
          MODE=$(cat "$CONFIG_FILE" 2>/dev/null || echo "universal")
      fi

      # Log file for debugging (optional)
      LOG_FILE="${configDir}/debug.log"
      log() {
          if [ "''${ZWIFT_MEDIA_DEBUG:-0}" = "1" ]; then
              echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
          fi
      }

      log "Sending keystroke: $KEYSTROKE (mode: $MODE)"

      # List of browsers in priority order
      BROWSERS=(
          "Google Chrome"
          "Arc"
          "Firefox"
          "Safari"
          "Brave Browser"
      )

      # Find the first running browser
      BROWSER=""
      for b in "''${BROWSERS[@]}"; do
          if pgrep -x "$b" > /dev/null 2>&1 || pgrep -f "$b.app" > /dev/null 2>&1; then
              BROWSER="$b"
              log "Found running browser: $BROWSER"
              break
          fi
      done

      if [ -z "$BROWSER" ]; then
          log "No browser running"
          echo "No browser running" >&2
          exit 1
      fi

      # Get current frontmost application to restore focus
      CURRENT_APP=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null || echo "")
      log "Current app: $CURRENT_APP"

      # Send the keystroke to the browser and return focus
      osascript <<EOF
      tell application "System Events"
          -- Store current frontmost process name
          set currentProcess to name of first process whose frontmost is true
      end tell

      -- Activate browser and send keystroke
      tell application "$BROWSER"
          activate
      end tell

      delay 0.1

      tell application "System Events"
          $KEYSTROKE
      end tell

      delay 0.1

      -- Return to original app using System Events (works with process names like ZwiftAppSilicon)
      tell application "System Events"
          set frontmost of process currentProcess to true
      end tell
      EOF

      log "Keystroke sent successfully"
    '';
  };

  # Play/Pause script
  playPauseScript = pkgs.writeShellApplication {
    name = "zwift-media-play-pause";
    runtimeInputs = [ sendToBrowserScript ];
    text = ''
      #!/bin/bash
      # Play/Pause media in browser
      set -euo pipefail

      CONFIG_FILE="${configDir}/mode.conf"
      MODE="universal"
      if [ -f "$CONFIG_FILE" ]; then
          MODE=$(cat "$CONFIG_FILE" 2>/dev/null || echo "universal")
      fi

      if [ "$MODE" = "youtube" ]; then
          # YouTube: k key
          zwift-media-send-to-browser 'keystroke "k"'
      else
          # Universal: space bar
          zwift-media-send-to-browser 'keystroke space'
      fi
    '';
  };

  # Skip Forward script
  skipForwardScript = pkgs.writeShellApplication {
    name = "zwift-media-skip-forward";
    runtimeInputs = [ sendToBrowserScript ];
    text = ''
      #!/bin/bash
      # Skip forward 10 seconds in browser media
      set -euo pipefail

      CONFIG_FILE="${configDir}/mode.conf"
      MODE="universal"
      if [ -f "$CONFIG_FILE" ]; then
          MODE=$(cat "$CONFIG_FILE" 2>/dev/null || echo "universal")
      fi

      if [ "$MODE" = "youtube" ]; then
          # YouTube: l key
          zwift-media-send-to-browser 'keystroke "l"'
      else
          # Universal: right arrow (key code 124)
          zwift-media-send-to-browser 'key code 124'
      fi
    '';
  };

  # Skip Back script
  skipBackScript = pkgs.writeShellApplication {
    name = "zwift-media-skip-back";
    runtimeInputs = [ sendToBrowserScript ];
    text = ''
      #!/bin/bash
      # Skip back 10 seconds in browser media
      set -euo pipefail

      CONFIG_FILE="${configDir}/mode.conf"
      MODE="universal"
      if [ -f "$CONFIG_FILE" ]; then
          MODE=$(cat "$CONFIG_FILE" 2>/dev/null || echo "universal")
      fi

      if [ "$MODE" = "youtube" ]; then
          # YouTube: j key
          zwift-media-send-to-browser 'keystroke "j"'
      else
          # Universal: left arrow (key code 123)
          zwift-media-send-to-browser 'key code 123'
      fi
    '';
  };

  # Mode switcher script
  modeSwitcherScript = pkgs.writeShellApplication {
    name = "zwift-media-mode";
    runtimeInputs = [ ];
    text = ''
      #!/bin/bash
      # Switch between YouTube and Universal modes
      # Usage: zwift-media-mode [youtube|universal|toggle|status]

      set -euo pipefail

      CONFIG_FILE="${configDir}/mode.conf"
      mkdir -p "${configDir}"

      get_mode() {
          if [ -f "$CONFIG_FILE" ]; then
              cat "$CONFIG_FILE"
          else
              echo "universal"
          fi
      }

      set_mode() {
          echo "$1" > "$CONFIG_FILE"
          echo "Mode set to: $1"
      }

      case "''${1:-status}" in
          youtube)
              set_mode "youtube"
              ;;
          universal)
              set_mode "universal"
              ;;
          toggle)
              current=$(get_mode)
              if [ "$current" = "youtube" ]; then
                  set_mode "universal"
              else
                  set_mode "youtube"
              fi
              ;;
          status)
              echo "Current mode: $(get_mode)"
              echo ""
              echo "Available modes:"
              echo "  youtube   - Uses j/k/l keys (YouTube shortcuts)"
              echo "  universal - Uses arrows/space (works with most players)"
              ;;
          *)
              echo "Usage: $0 [youtube|universal|toggle|status]" >&2
              exit 1
              ;;
      esac
    '';
  };

  # Test script to verify everything works
  testScript = pkgs.writeShellApplication {
    name = "zwift-media-test";
    runtimeInputs = [
      playPauseScript
      skipForwardScript
      skipBackScript
      modeSwitcherScript
    ];
    text = ''
      #!/bin/bash
      # Test the zwift-media scripts

      set -euo pipefail

      echo "=== Zwift Media Control Test ==="
      echo ""
      echo "Current mode:"
      zwift-media-mode status
      echo ""
      echo "Testing browser detection..."

      BROWSERS=(
          "Google Chrome"
          "Arc"
          "Firefox"
          "Safari"
          "Brave Browser"
      )

      FOUND=""
      for b in "''${BROWSERS[@]}"; do
          if pgrep -x "$b" > /dev/null 2>&1 || pgrep -f "$b.app" > /dev/null 2>&1; then
              echo "✓ Found running browser: $b"
              FOUND="$b"
              break
          fi
      done

      if [ -z "$FOUND" ]; then
          echo "✗ No browser running!"
          echo ""
          echo "Please start a browser and try again."
          exit 1
      fi

      echo ""
      echo "Ready to test. This will:"
      echo "1. Send play/pause keystroke"
      echo "2. Wait 2 seconds"
      echo "3. Send skip forward keystroke"
      echo "4. Wait 2 seconds"
      echo "5. Send skip back keystroke"
      echo ""
      read -rp "Press Enter to continue (Ctrl+C to cancel)..."

      echo ""
      echo "Sending play/pause..."
      zwift-media-play-pause
      sleep 2

      echo "Sending skip forward..."
      zwift-media-skip-forward
      sleep 2

      echo "Sending skip back..."
      zwift-media-skip-back

      echo ""
      echo "Test complete!"
      echo ""
      echo "If the media player responded to the controls, everything is working."
      echo "If not, check the following:"
      echo "  1. Make sure the browser window has a media player focused"
      echo "  2. Try switching modes: zwift-media-mode toggle"
      echo "  3. Enable debug logging: ZWIFT_MEDIA_DEBUG=1 zwift-media-play-pause"
    '';
  };

  # Karabiner configuration JSON
  # Xbox Controller Button Mapping:
  #   A = button1, B = button2, X = button4, Y = button5
  # To customize for other controllers, use Karabiner-EventViewer to find button codes
  karabinerConfig = {
    title = "Game Controller Media Controls";
    rules = [
      {
        description = "Controller: A Button = Play/Pause";
        manipulators = [
          {
            type = "basic";
            from = {
              pointing_button = "button1";  # Xbox A button
            };
            to = [
              {
                shell_command = "${lib.getExe playPauseScript}";
              }
            ];
            # Remove or modify conditions if you want this to work globally
            conditions = lib.optionals cfg.enableZwiftCondition [
              {
                type = "frontmost_application_if";
                file_paths = [
                  "Zwift/ZwiftAppSilicon$"
                ];
              }
            ];
          }
        ];
      }
      {
        description = "Controller: Y Button = Skip Forward 10s";
        manipulators = [
          {
            type = "basic";
            from = {
              pointing_button = "button5";  # Xbox Y button
            };
            to = [
              {
                shell_command = "${lib.getExe skipForwardScript}";
              }
            ];
            conditions = lib.optionals cfg.enableZwiftCondition [
              {
                type = "frontmost_application_if";
                file_paths = [
                  "Zwift/ZwiftAppSilicon$"
                ];
              }
            ];
          }
        ];
      }
      {
        description = "Controller: X Button = Skip Back 10s";
        manipulators = [
          {
            type = "basic";
            from = {
              pointing_button = "button4";  # Xbox X button
            };
            to = [
              {
                shell_command = "${lib.getExe skipBackScript}";
              }
            ];
            conditions = lib.optionals cfg.enableZwiftCondition [
              {
                type = "frontmost_application_if";
                file_paths = [
                  "Zwift/ZwiftAppSilicon$"
                ];
              }
            ];
          }
        ];
      }
      {
        description = "Controller: B Button = Toggle YouTube/Universal Mode";
        manipulators = [
          {
            type = "basic";
            from = {
              pointing_button = "button2";  # Xbox B button
            };
            to = [
              {
                shell_command = "${lib.getExe modeSwitcherScript} toggle";
              }
            ];
            conditions = lib.optionals cfg.enableZwiftCondition [
              {
                type = "frontmost_application_if";
                file_paths = [
                  "Zwift/ZwiftAppSilicon$"
                ];
              }
            ];
          }
        ];
      }
    ];
  };

  # README content
  readmeContent = ''
    # Game Controller Media Controls

    Control media playback in your browser using a game controller (Xbox, etc.),
    even when another app like Zwift is the active window.

    ## How It Works

    1. **Karabiner-Elements** detects button presses from your game controller
    2. **Helper scripts** send keystrokes to the first running browser
    3. **AppleScript** briefly activates the browser, sends the key, and returns focus

    ## Quick Start

    ### 1. Connect Your Controller

    Connect your game controller via USB. Bluetooth may work but USB is more reliable
    for Karabiner to detect the device.

    ### 2. Verify Button Codes (Optional)

    The default configuration is set up for Xbox controllers:
    - A = button1 (Play/Pause)
    - B = button2 (Toggle Mode)
    - X = button4 (Skip Back 10s)
    - Y = button5 (Skip Forward 10s)

    For other controllers, use **Karabiner-EventViewer** to discover button codes:
    1. Open Karabiner-EventViewer
    2. Press buttons and note the `pointing_button` values
    3. Edit `~/.config/karabiner/assets/complex_modifications/zwift-media.json`

    ### 3. Enable the Modification

    1. Open **Karabiner-Elements Preferences**
    2. Go to **Complex Modifications** tab
    3. Click **Add rule**
    4. Find "Game Controller Media Controls" and enable the rules you want

    ### 4. Test the Controls

    Run the test script:
    ```bash
    zwift-media-test
    ```

    Or test individual commands:
    ```bash
    zwift-media-play-pause
    zwift-media-skip-forward
    zwift-media-skip-back
    ```

    ## Button Mappings (Xbox Controller)

    | Button | Action |
    |--------|--------|
    | A | Play/Pause |
    | Y | Skip Forward 10s |
    | X | Skip Back 10s |
    | B | Toggle YouTube/Universal mode |

    ## Modes

    Two modes are available for different media players:

    ### YouTube Mode (j/k/l keys)
    - **Play/Pause**: `k`
    - **Skip Forward**: `l`
    - **Skip Back**: `j`

    ### Universal Mode (arrows/space)
    - **Play/Pause**: `Space`
    - **Skip Forward**: `Right Arrow`
    - **Skip Back**: `Left Arrow`

    Switch modes:
    ```bash
    zwift-media-mode youtube    # Switch to YouTube mode
    zwift-media-mode universal  # Switch to Universal mode
    zwift-media-mode toggle     # Toggle between modes
    zwift-media-mode status     # Show current mode
    ```

    ## Supported Browsers

    The scripts detect browsers in this order:
    1. Google Chrome
    2. Arc
    3. Firefox
    4. Safari
    5. Brave Browser

    ## Troubleshooting

    ### No response from media player

    1. Make sure a browser is running with media playing
    2. The browser window should have the video/player focused
    3. Try switching modes: `zwift-media-mode toggle`
    4. Enable debug logging:
       ```bash
       ZWIFT_MEDIA_DEBUG=1 zwift-media-play-pause
       cat ~/.config/zwift-media/debug.log
       ```

    ### Accessibility permissions

    Karabiner-Elements and Terminal/your shell need Accessibility permissions:
    1. Go to **System Preferences > Privacy & Security > Accessibility**
    2. Ensure Karabiner-Elements and Terminal are enabled

    ### Brief window flash

    The AppleScript approach requires briefly activating the browser window.
    This causes a minimal visual flash. The delay is kept as short as possible
    (50ms) to minimize the effect.

    Alternative approaches (if flash is unacceptable):
    - Use browser extensions that listen for global hotkeys
    - Use a media key daemon that doesn't require window activation

    ### Key codes not working

    If the Karabiner rules don't trigger:
    1. Re-check key codes in Karabiner-EventViewer
    2. Make sure the device is recognized by Karabiner
    3. Check if device needs to be added to Karabiner's device list

    ## Files

    - `~/.config/zwift-media/mode.conf` - Current mode setting
    - `~/.config/zwift-media/debug.log` - Debug log (when enabled)
    - `~/.config/karabiner/assets/complex_modifications/zwift-media.json` - Karabiner rules

    ## Commands

    | Command | Description |
    |---------|-------------|
    | `zwift-media-play-pause` | Send play/pause to browser |
    | `zwift-media-skip-forward` | Skip forward 10 seconds |
    | `zwift-media-skip-back` | Skip back 10 seconds |
    | `zwift-media-mode` | Switch/check playback mode |
    | `zwift-media-test` | Test the setup |
    | `zwift-media-send-to-browser` | Low-level keystroke sender |

    ## Disabling

    To disable this feature:

    1. In your Nix configuration, set:
       ```nix
       programs.zwift-media.enable = false;
       ```
    2. Run `nixswitch`

    Or temporarily disable in Karabiner:
    1. Open Karabiner-Elements Preferences
    2. Go to Complex Modifications
    3. Disable the Zwift Ride rules

    ## Uninstall

    To completely remove:

    1. Disable in Nix configuration (see above)
    2. Run `nixswitch`
    3. Remove the Karabiner rule file:
       ```bash
       rm ~/.config/karabiner/assets/complex_modifications/zwift-media.json
       ```
    4. Remove the config directory:
       ```bash
       rm -rf ~/.config/zwift-media
       ```
  '';

in
{
  options.programs.zwift-media = {
    enable = lib.mkEnableOption "Zwift Ride media controls for browser playback";

    mode = lib.mkOption {
      type = lib.types.enum [ "youtube" "universal" ];
      default = "universal";
      description = ''
        Default playback mode.
        - youtube: Uses j/k/l keys (YouTube shortcuts)
        - universal: Uses arrows/space (works with most players)
      '';
    };

    enableZwiftCondition = lib.mkOption {
      type = lib.types.bool;
      default = true;  # Only trigger when Zwift is frontmost
      description = ''
        If true, media controls only work when Zwift is the frontmost application.
        If false, controls work globally.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # NOTE: Karabiner-Elements must be installed via Homebrew cask, not nixpkgs,
    # because it requires privileged system daemons that can't be sandboxed.
    # The homebrew cask is added in modules/darwin/default.nix
    home.packages = [
      sendToBrowserScript
      playPauseScript
      skipForwardScript
      skipBackScript
      modeSwitcherScript
      testScript
    ];

    # Create the config directory and mode file
    xdg.configFile = {
      "zwift-media/mode.conf" = {
        text = cfg.mode;
      };
      "zwift-media/README.md" = {
        text = readmeContent;
      };
      "karabiner/assets/complex_modifications/zwift-media.json" = {
        text = builtins.toJSON karabinerConfig;
      };
    };

    # Activation script to ensure directories exist
    home.activation.zwiftMedia = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "${configDir}"
    '';
  };
}
