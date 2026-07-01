#!/usr/bin/env bats

load test_helper

@test "add then list shows the profile" {
  run "$GA" add work --name "Work Person" --email work@enterprise.com --host github.com
  [ "$status" -eq 0 ]

  run "$GA" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"work"* ]]
  [[ "$output" == *"work@enterprise.com"* ]]
}

@test "add requires name and email in non-interactive mode" {
  run "$GA" add broken --host github.com
  [ "$status" -ne 0 ]
  [[ "$output" == *"--name"* || "$output" == *"--email"* ]]
}

@test "invalid profile names are rejected" {
  run "$GA" add "bad name" --name X --email x@y.z
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid profile name"* ]]
}

@test "adding a profile does NOT create any matching rule" {
  "$GA" add work --name W --email w@e.com --host github.acme.com >/dev/null
  run "$GA" rule list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no rules defined"* ]]
}

@test "remove deletes the profile and its rules" {
  add_two_profiles
  "$GA" rule add github.com/acme work >/dev/null
  run "$GA" remove work
  [ "$status" -eq 0 ]

  run "$GA" list
  [[ "$output" != *"work@enterprise.com"* ]]

  run "$GA" rule list
  [[ "$output" != *"github.com/acme"* ]]
}

@test "profiles round-trip all fields via git config -f" {
  "$GA" add work --name "W P" --email w@e.com --host github.com \
    --ssh-key '~/.ssh/id_work' --signing-key '~/.ssh/id_work.pub' \
    --gpg-format ssh --sign true --credential-user wuser >/dev/null

  run git config -f "$GIT_ACCOUNT_CONFIG_DIR/config" --get profile.work.email
  [ "$output" = "w@e.com" ]
  run git config -f "$GIT_ACCOUNT_CONFIG_DIR/config" --get profile.work.gpgformat
  [ "$output" = "ssh" ]
  run git config -f "$GIT_ACCOUNT_CONFIG_DIR/config" --get profile.work.credentialuser
  [ "$output" = "wuser" ]
}
