#!/usr/bin/env bats

load test_helper

# A local bare repo we can clone over the file transport, so tests never touch
# the network. The forced -c core.sshCommand is harmless here (file transport
# ignores ssh), which lets us assert the account wiring without real auth.
make_bare_origin() {
  local origin="$TMP/origin.git"
  git init -q --bare "$origin"
  printf '%s\n' "$origin"
}

@test "clone --as pins the named profile into the new repo" {
  add_two_profiles
  origin="$(make_bare_origin)"

  run bash -c "cd '$TMP' && '$GA' clone --as work '$origin' cloned"
  [ "$status" -eq 0 ]
  [ "$(git -C "$TMP/cloned" config --local --get account.profile)" = "work" ]
  [ "$(git -C "$TMP/cloned" config --local --get user.email)" = "work@enterprise.com" ]
}

@test "clone --as with an ssh key writes core.sshCommand in the new repo" {
  "$GA" add work --name W --email w@e.com --host github.com --ssh-key '~/.ssh/id_work' >/dev/null
  origin="$(make_bare_origin)"

  run bash -c "cd '$TMP' && '$GA' clone --as work '$origin' cloned"
  [ "$status" -eq 0 ]
  [[ "$(git -C "$TMP/cloned" config --local --get core.sshCommand)" == *"$HOME/.ssh/id_work"* ]]
  [[ "$(git -C "$TMP/cloned" config --local --get core.sshCommand)" == *"IdentitiesOnly=yes"* ]]
}

@test "clone --as rejects an unknown profile before cloning" {
  origin="$(make_bare_origin)"

  run bash -c "cd '$TMP' && '$GA' clone --as nope '$origin' cloned"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no such profile"* ]]
  [ ! -d "$TMP/cloned" ]
}

@test "clone without a match still succeeds (apply is non-fatal)" {
  add_two_profiles   # both on github.com; a local path has no host -> no match
  origin="$(make_bare_origin)"

  run bash -c "cd '$TMP' && '$GA' clone '$origin' cloned < /dev/null"
  [ "$status" -eq 0 ]
  [ -d "$TMP/cloned/.git" ]
}

@test "clone derives the target dir like git when none is given" {
  add_two_profiles
  origin="$(make_bare_origin)"   # basename origin.git -> dir "origin"

  run bash -c "cd '$TMP' && '$GA' clone --as work '$origin'"
  [ "$status" -eq 0 ]
  [ "$(git -C "$TMP/origin" config --local --get account.profile)" = "work" ]
}
