# shellcheck shell=bash
# Apply a profile to the current repo: identity + auth + signing, all in local config.

apply_profile() {
  local name="$1"
  profile_require "$name"
  require_repo

  local uname uemail
  uname="$(profile_get "$name" name || true)"
  uemail="$(profile_get "$name" email || true)"

  [ -n "$uname" ]  && local_set user.name  "$uname"
  [ -n "$uemail" ] && local_set user.email "$uemail"

  # Marker so the plugin and the guard hook know which profile is active.
  local_set account.profile "$name"

  apply_auth "$name"
  apply_signing "$name"
}
