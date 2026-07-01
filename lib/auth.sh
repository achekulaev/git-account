# shellcheck shell=bash
# Per-repo authentication wiring (SSH by default, optional HTTPS username hint).

# Echo the ssh command a profile uses for auth (empty when it has no key).
# IdentitiesOnly avoids the agent offering the wrong key for the same host.
# Shared by apply_auth (repo-local config) and clone (one-shot -c override).
profile_ssh_command() {
  local sshkey
  sshkey="$(profile_get "$1" sshkey || true)"
  [ -n "$sshkey" ] || return 0
  sshkey="$(expand_tilde "$sshkey")"
  printf 'ssh -i %s -o IdentitiesOnly=yes\n' "$sshkey"
}

# Apply auth settings from a profile into the current repo's local config.
apply_auth() {
  local name="$1" sshcmd host cred

  sshcmd="$(profile_ssh_command "$name")"
  if [ -n "$sshcmd" ]; then
    local_set core.sshCommand "$sshcmd"
  else
    # Clear any command a previous profile may have set.
    local_unset core.sshCommand
  fi

  # HTTPS: hint git which account to use for this host so the credential
  # helper can resolve the right stored token.
  host="$(profile_get "$name" host || true)"
  cred="$(profile_get "$name" credentialuser || true)"
  if [ -n "$host" ] && [ -n "$cred" ]; then
    local_set "credential.https://$host.username" "$cred"
  fi
}
