# Placeholder: plain, unconfigured neovim so EDITOR works everywhere.
# Replaced by the real config in the neovim step.
{ ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true; # sets EDITOR=nvim
  };
}
