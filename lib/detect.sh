# shellcheck shell=bash
# shellcheck disable=SC2034  # GA_DETECT_* / GA_HOST / GA_OWNER are consumed by the entrypoint
# Remote-URL parsing and profile auto-detection with a confidence signal.

# Parse a git remote URL into GA_HOST and GA_OWNER.
# Handles scp-like (git@host:owner/repo.git), ssh://, https:// and bare host:path.
parse_remote_url() {
  local url="$1" rest host path
  GA_HOST=""; GA_OWNER=""
  [ -z "$url" ] && return 1

  case "$url" in
    *://*)
      rest="${url#*://}"        # drop scheme://
      rest="${rest#*@}"         # drop optional user@
      host="${rest%%/*}"        # host[:port]
      host="${host%%:*}"        # drop :port
      path="${rest#*/}"
      ;;
    *@*:*)
      rest="${url#*@}"          # host:owner/repo
      host="${rest%%:*}"
      path="${rest#*:}"
      ;;
    *:*)
      host="${url%%:*}"
      path="${url#*:}"
      ;;
    *)
      host=""
      path="$url"
      ;;
  esac

  path="${path#/}"
  GA_HOST="$host"
  GA_OWNER="${path%%/*}"
  [ -n "$GA_HOST" ]
}

# Profiles that declared this host in profile.<name>.host.
_profiles_with_host() {
  local host="$1" out key val name
  out="$(git config -f "$GA_CONFIG_FILE" --get-regexp '^profile\..+\.host$' 2>/dev/null || true)"
  [ -n "$out" ] || return 0
  while read -r key val; do
    if [ "$val" = "$host" ]; then
      name="${key#profile.}"; printf '%s\n' "${name%.host}"
    fi
  done <<< "$out"
  return 0
}

# Profiles whose rules match an exact pattern (host or host/owner).
_profiles_with_rule() {
  local want="$1" out key val
  out="$(git config -f "$GA_CONFIG_FILE" --get-regexp '^rule\.' 2>/dev/null || true)"
  [ -n "$out" ] || return 0
  while read -r key val; do
    if [ "$val" = "$want" ]; then printf '%s\n' "${key#rule.}"; fi
  done <<< "$out"
  return 0
}

_uniq_nonempty() { sort -u | sed '/^$/d'; }

# Choose a profile from the already-parsed GA_HOST/GA_OWNER.
# Sets: GA_DETECT_STATE (confident|ambiguous|none),
#       GA_DETECT_PROFILE (when confident),
#       GA_DETECT_CANDIDATES (newline list when ambiguous).
_detect_from_host_owner() {
  # Most specific tier wins: owner rule > host rule > profile host field.
  local chosen
  chosen="$(_profiles_with_rule "$GA_HOST/$GA_OWNER" | _uniq_nonempty)"
  if [ -z "$chosen" ]; then
    chosen="$(_profiles_with_rule "$GA_HOST" | _uniq_nonempty)"
  fi
  if [ -z "$chosen" ]; then
    chosen="$(_profiles_with_host "$GA_HOST" | _uniq_nonempty)"
  fi

  local n
  n="$(printf '%s\n' "$chosen" | sed '/^$/d' | wc -l | tr -d ' ')"
  GA_DETECT_CANDIDATES="$chosen"
  if [ "$n" -eq 1 ]; then
    GA_DETECT_STATE="confident"; GA_DETECT_PROFILE="$chosen"
  elif [ "$n" -gt 1 ]; then
    GA_DETECT_STATE="ambiguous"
  else
    GA_DETECT_STATE="none"
  fi
}

# Detect the profile for the current repo (from remote.origin.url).
# Sets GA_DETECT_STATE (confident|ambiguous|none|noremote) and friends.
detect_for_repo() {
  GA_DETECT_STATE="none"; GA_DETECT_PROFILE=""; GA_DETECT_CANDIDATES=""

  local url; url="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [ -z "$url" ]; then GA_DETECT_STATE="noremote"; return 0; fi
  if ! parse_remote_url "$url"; then GA_DETECT_STATE="noremote"; return 0; fi

  _detect_from_host_owner
}

# Detect the profile for an explicit remote URL, before any repo exists.
# Used by `git account clone` to pick the key for the initial handshake.
detect_for_url() {
  GA_DETECT_STATE="none"; GA_DETECT_PROFILE=""; GA_DETECT_CANDIDATES=""

  local url="${1:-}"
  if [ -z "$url" ]; then GA_DETECT_STATE="noremote"; return 0; fi
  if ! parse_remote_url "$url"; then GA_DETECT_STATE="noremote"; return 0; fi

  _detect_from_host_owner
}
