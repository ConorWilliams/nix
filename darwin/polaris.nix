# polaris: this Mac's own system settings, on top of every Mac's (./.).
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
  imports = [ ./. ];

  # nix-darwin's equivalent of home.stateVersion. Set once, never bump.
  system.stateVersion = 6;

  # The user that per-user system settings (Homebrew, macOS defaults)
  # apply to.
  system.primaryUser = "main";

  # Its name (kept by ./default.nix; set it by hand the first time: README).
  networking.hostName = "polaris";

  # Its apps (Homebrew casks), added to every Mac's (./default.nix).
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

  # Its keyboard is British: the layout and input sources to match.
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
