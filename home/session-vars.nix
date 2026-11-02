# Home Manager's session variables (PATH additions, EDITOR, NH_FLAKE...)
# live in hm-session-vars.sh, which login shells, the desktop login and
# fish load. Home Manager's own version loads only once, marked by a
# variable that everything started later inherits, because loading it
# again would add the PATH entries again. But the mark outlives the
# variables (a desktop login inherits it from the systemd user manager,
# which a GNOME login filled, while PATH is reset), and it stops a
# switch's new variables reaching new shells.
#
# So this replaces the file with one that is safe to load any number of
# times, and is loaded every time. Each list variable built up by
# prepending (PATH and the like) keeps one copy of each entry: first the
# inherited value loses repeats (keeping first copies), then after Home
# Manager's additions only the copy already there stays. So new entries
# go first, existing ones keep their place (as fish_add_path does: a
# shell inside `nix develop` keeps the dev shell's tools first), and
# loading again changes nothing. fish gets the same file, translated by
# Home Manager (babelfish).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.home;
  inherit (config.lib) shell;

  # Every search variable, and any other one whose value refers to itself
  # (e.g. XDG_DATA_DIRS: "<dirs>${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}").
  refersToItself =
    name: value:
    lib.hasInfix ("$" + name) (toString value) || lib.hasInfix ("\${" + name) (toString value);
  lists = lib.unique (
    builtins.attrNames cfg.sessionSearchVariables
    ++ builtins.attrNames (lib.filterAttrs refersToItself cfg.sessionVariables)
  );

  # Drops empty entries, and every copy of an entry but the first (keep =
  # "first") or the last ("last").
  dedupe = keep: name: /* bash */ ''
    if [ -n "''${${name}-}" ]; then
      ${name}=$(__hm_list="${"$" + name}" awk -v last=${
        if keep == "last" then "1" else "0"
      } 'BEGIN { n = split(ENVIRON["__hm_list"], a, ":"); for (j = 1; j <= n; j++) { i = last ? n + 1 - j : j; if (a[i] != "" && !s[a[i]]++) k[i] = 1 } for (i = 1; i <= n; i++) if (k[i]) o = o (o == "" ? "" : ":") a[i]; print o }')
      export ${name}
    fi
  '';
in
{
  # Home Manager's own text (home-environment.nix) without its "only once"
  # check, and with the lists de-duplicated before and after.
  home.sessionVariablesPackage = lib.mkForce (
    pkgs.writeTextFile {
      name = "hm-session-vars.sh";
      destination = "/etc/profile.d/hm-session-vars.sh";
      text =
        lib.concatMapStrings (dedupe "first") lists
        + ''
          ${shell.exportAll cfg.sessionVariables}
        ''
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: values: shell.export name (shell.prependToVar ":" name values)
          ) cfg.sessionSearchVariables
        )
        + "\n"
        + cfg.sessionVariablesExtra
        + lib.concatMapStrings (dedupe "last") lists;
    }
  );
}
