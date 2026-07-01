# shellcheck shell=bash
# Shared helpers: config paths, logging, small utilities.
# Sourced by the git-account entrypoint; not meant to run standalone.

# Config location (XDG-aware, overridable for tests via GIT_ACCOUNT_CONFIG_DIR).
GA_CONFIG_DIR="${GIT_ACCOUNT_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/git-account}"
GA_CONFIG_FILE="$GA_CONFIG_DIR/config"

# ANSI colors, disabled when not writing to a terminal or NO_COLOR is set.
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  GA_RED=$'\033[31m'; GA_GRN=$'\033[32m'; GA_YEL=$'\033[33m'
  GA_BLU=$'\033[34m'; GA_RST=$'\033[0m'
else
  GA_RED=; GA_GRN=; GA_YEL=; GA_BLU=; GA_RST=
fi

die()  { printf '%sgit-account: %s%s\n' "$GA_RED" "$*" "$GA_RST" >&2; exit 1; }
warn() { printf '%sgit-account: %s%s\n' "$GA_YEL" "$*" "$GA_RST" >&2; }
info() { printf '%sgit-account:%s %s\n' "$GA_BLU" "$GA_RST" "$*" >&2; }
ok()   { printf '%sgit-account:%s %s\n' "$GA_GRN" "$GA_RST" "$*" >&2; }

# True when we can run the interactive wizard. GIT_ACCOUNT_ASSUME_TTY forces it
# on (used by tests to drive prompts via piped stdin).
is_tty() { [ -n "${GIT_ACCOUNT_ASSUME_TTY:-}" ] || { [ -t 0 ] && [ -t 1 ]; }; }

# Expand a leading ~ to $HOME (git config does not do this for us).
# shellcheck disable=SC2088  # the literal ~ patterns are intentional, not paths to expand
expand_tilde() {
  case "$1" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${1#\~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

ensure_config_dir() { mkdir -p "$GA_CONFIG_DIR"; }

# Split newline-separated text into the GA_LINES array (blank lines dropped).
# Portable replacement for bash 4's `mapfile`, since macOS ships bash 3.2.
split_lines() {
  GA_LINES=()
  local _line
  while IFS= read -r _line; do
    [ -n "$_line" ] && GA_LINES+=("$_line")
  done <<< "${1:-}"
}

# Read/write the plugin's own config file (reusing git as the ini parser).
cfg_get() { git config -f "$GA_CONFIG_FILE" --get "$1" 2>/dev/null; }
cfg_set() { ensure_config_dir; git config -f "$GA_CONFIG_FILE" "$1" "$2"; }
cfg_unset() { git config -f "$GA_CONFIG_FILE" --unset "$1" 2>/dev/null || true; }

require_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git repository."
}

# Local (repo) git config helpers.
local_get() { git config --local --get "$1" 2>/dev/null; }
local_set() { git config --local "$1" "$2"; }
local_unset() { git config --local --unset "$1" 2>/dev/null || true; }
