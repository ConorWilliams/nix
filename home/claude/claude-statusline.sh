# Claude Code status line, e.g.   Opus 5.5 | ~/nix@main | 58k/1000k | 5h 5%  7d 1%
# Over SSH the location gains user@host, like the shell prompt.
# Reads Claude's status JSON on stdin; jq and git are pinned by home/claude.nix.
# Runs in bash strict mode (set -euo pipefail), added by writeShellApplication.

# All fields in one jq call. \x1f (not tab) as separator, because bash's read
# merges runs of whitespace separators, which would shift empty fields.
IFS=$'\x1f' read -r model dir pct used size h5 d7 < <(jq -r '
  def pct: if . == null then "" else round end;
  [ .model.display_name,
    .workspace.current_dir,
    (.context_window.used_percentage | pct),
    .context_window.total_input_tokens,
    .context_window.context_window_size,
    (.rate_limits.five_hour.used_percentage | pct),
    (.rate_limits.seven_day.used_percentage | pct)
  ] | map(. // "" | tostring) | join("\u001f")')

# Colour a percentage: green under 50, yellow 50-79, red 80+.
color() {
  local c=32
  (($1 >= 50)) && c=33
  (($1 >= 80)) && c=31
  printf '\033[01;%sm%s\033[0m' "$c" "$2"
}

# Location: ~/path@branch, prefixed with user@host over SSH.
branch=$(git --no-optional-locks -C "$dir" branch --show-current 2>/dev/null || true)
where="${dir/#$HOME/\~}${branch:+@$branch}"
[[ -n ${SSH_CONNECTION:-} ]] && where="$USER@$(hostname -s):$where"

line=$(printf '\033[01;36m%s\033[0m' "$model")
line+=" | $(printf '\033[01;34m%s\033[0m' "$where")"
[[ -n $pct ]] && line+=" | $(color "$pct" "$((used / 1000))k/$((size / 1000))k")"
limits=""
[[ -n $h5 ]] && limits+="$(color "$h5" "5h $h5%")  "
[[ -n $d7 ]] && limits+="$(color "$d7" "7d $d7%")"
[[ -n $limits ]] && line+=" | ${limits%  }"

printf '%s' "${line// | /$'\033[90m | \033[0m'}" # dim separators

# One spacer row below. Claude Code drops blank lines from status line output,
# so the row holds a zero-width space (U+200B), which survives its trimming.
printf '\n​'
