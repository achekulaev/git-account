#!/usr/bin/env bats
#
# The interactive `git account add` wizard. GIT_ACCOUNT_ASSUME_TTY forces the
# interactive path so prompts can be driven from piped stdin.

load test_helper

cfg() { git config -f "$GIT_ACCOUNT_CONFIG_DIR/config" --get "$1"; }

@test "wizard prompts for missing fields and generates an SSH key on Enter" {
  # inputs: full name / email / host(blank->default) / ssh(blank->generate) / sign?(n)
  run env GIT_ACCOUNT_ASSUME_TTY=1 "$GA" add work <<'EOF'
John Smith
john@corp.com


n
EOF
  [ "$status" -eq 0 ]
  [ "$(cfg profile.work.name)" = "John Smith" ]
  [ "$(cfg profile.work.email)" = "john@corp.com" ]
  [ "$(cfg profile.work.host)" = "github.com" ]

  key="$(cfg profile.work.sshkey)"
  [ "$key" = "$HOME/.ssh/id_ed25519_work" ]
  [ -f "$HOME/.ssh/id_ed25519_work" ]
  [ -f "$HOME/.ssh/id_ed25519_work.pub" ]

  # It must tell the user where to add the public key.
  [[ "$output" == *"$HOME/.ssh/id_ed25519_work.pub"* ]]
  [[ "$output" == *"New SSH key"* ]]
}

@test "wizard can reuse the generated SSH key for signing" {
  run env GIT_ACCOUNT_ASSUME_TTY=1 "$GA" add work <<'EOF'
John Smith
john@corp.com
github.com

y
EOF
  [ "$status" -eq 0 ]
  [ "$(cfg profile.work.gpgformat)" = "ssh" ]
  [ "$(cfg profile.work.sign)" = "true" ]
  [ "$(cfg profile.work.signingkey)" = "$HOME/.ssh/id_ed25519_work.pub" ]
}

@test "wizard 'none' skips SSH key generation" {
  run env GIT_ACCOUNT_ASSUME_TTY=1 "$GA" add nokey <<'EOF'
No Key
nokey@corp.com
github.com
none
EOF
  [ "$status" -eq 0 ]
  run cfg profile.nokey.sshkey
  [ "$status" -ne 0 ]  # unset
  [ ! -e "$HOME/.ssh/id_ed25519_nokey" ]
}

@test "wizard prompts for the account id when omitted" {
  run env GIT_ACCOUNT_ASSUME_TTY=1 "$GA" add <<'EOF'
personal
Me Myself
me@example.com
github.com
none
EOF
  [ "$status" -eq 0 ]
  [ "$(cfg profile.personal.email)" = "me@example.com" ]
}

@test "flags provided are not re-prompted (host flag honored, ssh skipped)" {
  # Only email is missing; provide it, then skip ssh.
  run env GIT_ACCOUNT_ASSUME_TTY=1 "$GA" add work --name "Work Person" --host github.acme.com <<'EOF'
work@acme.com
none
EOF
  [ "$status" -eq 0 ]
  [ "$(cfg profile.work.host)" = "github.acme.com" ]
  [ "$(cfg profile.work.email)" = "work@acme.com" ]
  [ "$(cfg profile.work.name)" = "Work Person" ]
}
