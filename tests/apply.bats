#!/usr/bin/env bats

load test_helper

@test "use writes identity + account.profile marker into local config" {
  "$GA" add work --name "Work Person" --email work@enterprise.com --host github.com >/dev/null
  repo="$(make_repo r)"

  run bash -c "cd '$repo' && '$GA' use work"
  [ "$status" -eq 0 ]
  [ "$(git -C "$repo" config --local --get user.name)" = "Work Person" ]
  [ "$(git -C "$repo" config --local --get user.email)" = "work@enterprise.com" ]
  [ "$(git -C "$repo" config --local --get account.profile)" = "work" ]
}

@test "ssh key produces core.sshCommand with IdentitiesOnly" {
  "$GA" add work --name W --email w@e.com --host github.com --ssh-key '~/.ssh/id_work' >/dev/null
  repo="$(make_repo r)"

  bash -c "cd '$repo' && '$GA' use work"
  run git -C "$repo" config --local --get core.sshCommand
  [[ "$output" == *"$HOME/.ssh/id_work"* ]]
  [[ "$output" == *"IdentitiesOnly=yes"* ]]
}

@test "ssh signing sets user.signingkey, gpg.format and commit.gpgsign" {
  "$GA" add work --name W --email w@e.com --host github.com \
    --signing-key '~/.ssh/id_work.pub' --gpg-format ssh --sign true >/dev/null
  repo="$(make_repo r)"

  bash -c "cd '$repo' && '$GA' use work"
  [ "$(git -C "$repo" config --local --get gpg.format)" = "ssh" ]
  [ "$(git -C "$repo" config --local --get commit.gpgsign)" = "true" ]
  [[ "$(git -C "$repo" config --local --get user.signingkey)" == *"$HOME/.ssh/id_work.pub"* ]]
}

@test "switching profiles clears the previous profile's ssh command" {
  "$GA" add withkey --name A --email a@e.com --host github.com --ssh-key '~/.ssh/id_a' >/dev/null
  "$GA" add nokey   --name B --email b@e.com --host github.com >/dev/null
  repo="$(make_repo r)"

  bash -c "cd '$repo' && '$GA' use withkey"
  [ -n "$(git -C "$repo" config --local --get core.sshCommand || true)" ]

  bash -c "cd '$repo' && '$GA' use nokey"
  run git -C "$repo" config --local --get core.sshCommand
  [ "$status" -ne 0 ]  # unset
}

# Regression: the interactive picker uses an array split that must work on the
# bash 3.2 shipped by macOS (no `mapfile`). Drive the prompt from piped stdin.
@test "interactive ambiguous apply lets you pick a profile (bash 3.2 safe)" {
  add_two_profiles
  "$GA" rule add github.com personal >/dev/null   # two host rules -> ambiguous
  "$GA" rule add github.com work >/dev/null
  repo="$(make_repo r git@github.com:someone/thing.git)"

  run env GIT_ACCOUNT_ASSUME_TTY=1 bash -c "cd '$repo' && '$GA'" <<< "2"
  [ "$status" -eq 0 ]
  [[ "$output" != *"mapfile"* ]]
  [ "$(git -C "$repo" config --local --get account.profile)" = "work" ]
}

# An assigned repo must not re-prompt on a later `apply`, even when the remote
# is ambiguous (this is what `clone --as`/`use` bake in).
@test "apply honors an already-assigned profile instead of re-detecting" {
  add_two_profiles   # both match github.com -> would be ambiguous on detect
  repo="$(make_repo r git@github.com:Orion-Advisor-Tech/thing.git)"
  bash -c "cd '$repo' && '$GA' use work"   # bake in the assignment

  # No stdin: if it tried to prompt it would fail; it must stay silent instead.
  run bash -c "cd '$repo' && '$GA' apply < /dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already assigned"* ]]
  [ "$(git -C "$repo" config --local --get account.profile)" = "work" ]
}

@test "https credential username hint is written when configured" {
  "$GA" add work --name W --email w@e.com --host github.com --credential-user wuser >/dev/null
  repo="$(make_repo r)"

  bash -c "cd '$repo' && '$GA' use work"
  [ "$(git -C "$repo" config --local --get 'credential.https://github.com.username')" = "wuser" ]
}
