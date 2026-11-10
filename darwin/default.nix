# The Macs' system settings (nix-darwin)
{ config, lib, ... }:

# TODO: the division between default.nix and polaris.nix is a
# little arbitrary because at the moment I only have one Mac.

{
  # Each Mac's name for all three of macOS's names, so it stays put: macOS
  # renames a Mac on a network name clash.
  networking = {
    localHostName = config.networking.hostName;
    computerName = config.networking.hostName;
  };

  # Upstream Nix; nix-darwin manages its daemon and settings.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Hard-link identical files in the store, on a schedule.
  nix.optimise.automatic = true;

  # GUI apps via Homebrew casks
  homebrew = {
    enable = true;
    casks = [ "kitty" ];
    onActivation.cleanup = "uninstall";
  };

  # Weekly clean-up of old versions and unused files, as root.
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };

  # sudo asks for a fingerprint (Touch ID).
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true; # inside zellij too.
  };

  system = {
    # Remap caps-lock
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    # Free keys that overlap with Zellij/AeroSpace.
    activationScripts.postActivation.text =
      let
        disabledHotkeys = [
          28 # Screen capture: Cmd+Shift+3
          30 # Region capture: Cmd+Shift+4
          32 # Mission Control: Ctrl+Up
          34 # ^ slow: Ctrl+Shift+Up
          33 # App windows: Ctrl+Down
          35 # ^ slow: Ctrl+Shift+Down
          79 # Space left: Ctrl+Left
          80 # ^ slow: Ctrl+Shift+Left
          81 # Space right: Ctrl+Right
          82 # ^ slow: Ctrl+Shift+Right
          184 # Capture toolbar: Cmd+Shift+5
        ];
      in
      lib.mkAfter /* bash */ ''
        for key in ${lib.concatMapStringsSep " " toString disabledHotkeys}; do
          sudo -u ${lib.escapeShellArg config.system.primaryUser} /usr/bin/defaults write \
            com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$key" \
            '<dict><key>enabled</key><false/></dict>'
        done
      '';

    defaults = {
      # Faster keys/trackpad
      NSGlobalDomain = {
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        "com.apple.trackpad.scaling" = 2.0;
      };

      # An empty Dock that hides itself.
      dock = {
        autohide = true;
        persistent-apps = [ ];
        persistent-others = [ ];
      };

      CustomUserPreferences.NSGlobalDomain = {
        AppleLanguages = [ "en-GB" ];
        AppleLocale = "en_GB";
      };
    };
  };
}
