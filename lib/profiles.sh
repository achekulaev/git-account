# shellcheck shell=bash
# Profile and rule storage, backed by ~/.config/git-account/config via `git config -f`.
#
# Layout:
#   profile.<name>.name           display name (user.name)
#   profile.<name>.email          user.email
#   profile.<name>.host           host used for auto-matching (e.g. github.com)
#   profile.<name>.sshkey         path to SSH private key (optional)
#   profile.<name>.signingkey     GPG key id or SSH key path (optional)
#   profile.<name>.gpgformat      "openpgp" or "ssh" (optional)
#   profile.<name>.sign           "true"/"false" (optional)
#   profile.<name>.credentialuser HTTPS username for credential.<host>.username (optional)
#   rule.<name>                   multi-valued match patterns: "host" or "host/owner"

# Valid profile names keep the git subsection unambiguous.
profile_valid_name() {
  case "$1" in
    ""|*[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

profile_get() { cfg_get "profile.$1.$2"; }
profile_set() { cfg_set "profile.$1.$2" "$3"; }

profile_exists() {
  git config -f "$GA_CONFIG_FILE" --get-regexp "^profile\.$1\." >/dev/null 2>&1
}

# Print all profile names, one per line.
profile_names() {
  local out
  out="$(git config -f "$GA_CONFIG_FILE" --name-only --get-regexp '^profile\..+\.email$' 2>/dev/null || true)"
  [ -n "$out" ] || return 0
  printf '%s\n' "$out" | sed -E 's/^profile\.(.+)\.email$/\1/' | sort
}

profile_require() {
  profile_exists "$1" || die "no such profile: '$1' (see: git account list)"
}

profile_remove() {
  local name="$1"
  git config -f "$GA_CONFIG_FILE" --remove-section "profile.$name" 2>/dev/null || true
  cfg_unset_all "rule.$name"
}

# Remove every value of a (possibly multi-valued) key.
cfg_unset_all() {
  git config -f "$GA_CONFIG_FILE" --unset-all "$1" 2>/dev/null || true
}

# --- rules -----------------------------------------------------------------

rule_add() {
  local name="$1" pattern="$2"
  ensure_config_dir
  # Avoid duplicate identical patterns for the same profile.
  if git config -f "$GA_CONFIG_FILE" --get-all "rule.$name" 2>/dev/null \
       | grep -Fxq -- "$pattern"; then
    return 0
  fi
  git config -f "$GA_CONFIG_FILE" --add "rule.$name" "$pattern"
}

rule_remove() {
  local name="$1" pattern="$2"
  git config -f "$GA_CONFIG_FILE" --unset-all "rule.$name" "^$(printf '%s' "$pattern" | sed 's/[.[\*^$]/\\&/g')$" 2>/dev/null || true
}

# Print "profile<TAB>pattern" for every rule.
rule_list() {
  local out
  out="$(git config -f "$GA_CONFIG_FILE" --get-regexp '^rule\.' 2>/dev/null || true)"
  [ -n "$out" ] || return 0
  printf '%s\n' "$out" | sed -E 's/^rule\.([^ ]+) (.*)$/\1\t\2/'
}
