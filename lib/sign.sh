# shellcheck shell=bash
# Per-repo commit/tag signing wiring (GPG or SSH signing keys).

# Apply signing settings from a profile into the current repo's local config.
apply_signing() {
  local name="$1" signingkey gpgformat sign

  signingkey="$(profile_get "$name" signingkey || true)"
  gpgformat="$(profile_get "$name" gpgformat || true)"
  sign="$(profile_get "$name" sign || true)"

  if [ -z "$signingkey" ]; then
    # No signing configured for this profile: leave repo signing untouched
    # only if we didn't set it; otherwise clear our previous settings.
    local_unset user.signingkey
    local_unset commit.gpgsign
    local_unset tag.gpgsign
    return 0
  fi

  # SSH signing keys are usually paths; expand a leading ~.
  if [ "$gpgformat" = "ssh" ]; then
    signingkey="$(expand_tilde "$signingkey")"
  fi

  local_set user.signingkey "$signingkey"
  [ -n "$gpgformat" ] && local_set gpg.format "$gpgformat"

  if [ "$sign" = "true" ]; then
    local_set commit.gpgsign true
    local_set tag.gpgsign true
  else
    local_unset commit.gpgsign
    local_unset tag.gpgsign
  fi
}
