# macOS preferences applied by nix-darwin at system switch.
{ ... }:

let
  britishKeyboard = {
    InputSourceKind = "Keyboard Layout";
    "KeyboardLayout ID" = 2;
    "KeyboardLayout Name" = "British";
  };
  pressAndHold = {
    "Bundle ID" = "com.apple.PressAndHold";
    InputSourceKind = "Non Keyboard Input Method";
  };
in
{
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      "com.apple.trackpad.scaling" = 2.0;
    };

    dock = {
      autohide = true;
      persistent-apps = [ ];
      persistent-others = [ ];
    };

    # nix-darwin writes these to both built-in and Bluetooth trackpad domains.
    trackpad = {
      Clicking = false;
      TrackpadRightClick = true;
    };

    # These preferences have no dedicated options in the pinned nix-darwin.
    CustomUserPreferences = {
      NSGlobalDomain = {
        AppleLanguages = [ "en-GB" ];
        AppleLocale = "en_GB";
      };
      "com.apple.HIToolbox" = {
        AppleCurrentKeyboardLayoutInputSourceID = "com.apple.keylayout.British";
        AppleEnabledInputSources = [
          britishKeyboard
          {
            "Bundle ID" = "com.apple.CharacterPaletteIM";
            InputSourceKind = "Non Keyboard Input Method";
          }
          pressAndHold
        ];
        AppleSelectedInputSources = [
          pressAndHold
          britishKeyboard
        ];
      };
    };
  };
}
