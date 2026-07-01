#!/usr/bin/env bats

load test_helper

@test "confident: owner-level rule selects the profile automatically" {
  add_two_profiles
  "$GA" rule add github.com/acme-corp work >/dev/null
  repo="$(make_repo r1 git@github.com:acme-corp/thing.git)"

  run bash -c "cd '$repo' && '$GA' apply"
  [ "$status" -eq 0 ]
  [ "$(git -C "$repo" config --local --get account.profile)" = "work" ]
  [ "$(git -C "$repo" config --local --get user.email)" = "work@enterprise.com" ]
}

@test "confident: single host rule applies silently" {
  "$GA" add solo --name Solo --email solo@example.com --host github.acme.com >/dev/null
  "$GA" rule add github.acme.com solo >/dev/null
  repo="$(make_repo r2 git@github.acme.com:team/repo.git)"

  run bash -c "cd '$repo' && '$GA' apply"
  [ "$status" -eq 0 ]
  [ "$(git -C "$repo" config --local --get account.profile)" = "solo" ]
}

@test "none: a profile's host field is not a matcher (no rule => no match)" {
  "$GA" add solo --name Solo --email solo@example.com --host github.acme.com >/dev/null
  repo="$(make_repo r2b git@github.acme.com:team/repo.git)"

  run bash -c "cd '$repo' && '$GA' apply < /dev/null"
  [ "$status" -ne 0 ]
  [[ "$output" == *"auto-detect"* || "$output" == *"Assign one"* ]]
}

@test "ambiguous: two host rules on the same host, non-interactive apply refuses" {
  add_two_profiles
  "$GA" rule add github.com personal >/dev/null
  "$GA" rule add github.com work >/dev/null
  repo="$(make_repo r3 git@github.com:someone/thing.git)"

  run bash -c "cd '$repo' && '$GA' apply < /dev/null"
  [ "$status" -ne 0 ]
  [[ "$output" == *"multiple profiles match"* ]]
}

@test "no remote: non-interactive apply refuses with guidance" {
  add_two_profiles
  repo="$(make_repo r4)"

  run bash -c "cd '$repo' && '$GA' apply < /dev/null"
  [ "$status" -ne 0 ]
  [[ "$output" == *"auto-detect"* || "$output" == *"Assign one"* ]]
}

@test "https remote URLs are parsed for host/owner" {
  add_two_profiles
  "$GA" rule add github.com/acme-corp work >/dev/null
  repo="$(make_repo r5 https://github.com/acme-corp/thing.git)"

  run bash -c "cd '$repo' && '$GA' apply"
  [ "$status" -eq 0 ]
  [ "$(git -C "$repo" config --local --get account.profile)" = "work" ]
}
