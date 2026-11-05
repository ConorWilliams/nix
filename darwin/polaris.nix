{ lib, ... }:

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
  imports = [ ./. ];

  # nix-darwin's equivalent of home.stateVersion. Set once, never bump.
  system.stateVersion = 6;

  homebrew.casks = [
    "adobe-creative-cloud"
    "google-chrome"
    "mullvad-vpn"
    "thunderbird"
    "tor-browser"
    "transmission"
    "vlc"
    "whatsapp"
  ];

  system.activationScripts.postActivation.text = lib.mkAfter ''
    '/Applications/Mullvad VPN.app/Contents/Resources/mullvad' auto-connect set on
  '';

  # It's a British keyboard.
  system.defaults.CustomUserPreferences."com.apple.HIToolbox" = {
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
}
