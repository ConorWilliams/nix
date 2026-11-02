# Home Manager's session variables (PATH additions, EDITOR, NH_FLAKE...)
# are loaded once and marked done, and everything started later inherits
# that mark, so a switch's new ones wouldn't reach running sessions (on
# Ubuntu desktops not even after logging out: home/gui/ubuntu reloads them
# at login). Loading them twice isn't harmless (each load adds the PATH
# entries again), so the file records which variables it holds, as a hash
# of them, in __hm_session_vars, and a stale or missing record is the only
# reason to reload. (A hash, as the file can't name its own store path.)
{ config, lib, ... }:

{
  options.hmSessionVarsStamp = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = builtins.hashString "sha256" (
      builtins.toJSON [
        config.home.sessionVariables
        config.home.sessionPath
      ]
    );
    description = "Identifies this generation's session variables; the session-variables file exports it as __hm_session_vars.";
  };

  config = {
    home.sessionVariablesExtra = /* bash */ ''
      export __hm_session_vars=${config.hmSessionVarsStamp}
    '';

    # fish: conf.d runs before config.fish, which loads them.
    xdg.configFile."fish/conf.d/hm-session-vars.fish".text = /* fish */ ''
      if test "$__hm_session_vars" != ${config.hmSessionVarsStamp}
        set -e __HM_SESS_VARS_SOURCED
      end
    '';
  };
}
