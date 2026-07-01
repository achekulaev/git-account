#!/usr/bin/env bats
#
# The core safety guarantee: enabling the global guard hook must NOT silently
# skip repo-local hooks or a previously-configured global hooks path.

load test_helper

# Assign the repo to a profile whose email matches, so the identity guard passes
# and we can isolate the chaining behavior.
setup_assigned_repo() {
  "$GA" add work --name "Work Person" --email work@enterprise.com --host github.com >/dev/null
  REPO="$(make_repo r git@github.com:acme/thing.git)"
  bash -c "cd '$REPO' && '$GA' use work" >/dev/null
  git -C "$REPO" config user.email work@enterprise.com
  echo "x" > "$REPO/file.txt"
  git -C "$REPO" add file.txt
}

do_commit() { git -C "$REPO" commit -q -m "$1"; }

@test "guard chains to a repo-local pre-commit hook (it still runs)" {
  setup_assigned_repo
  mkdir -p "$REPO/.git/hooks"
  cat > "$REPO/.git/hooks/pre-commit" <<EOF
#!/usr/bin/env bash
touch "$TMP/repo_hook_ran"
exit 0
EOF
  chmod +x "$REPO/.git/hooks/pre-commit"

  "$GA" install-hook >/dev/null

  run do_commit "with repo hook"
  [ "$status" -eq 0 ]
  [ -f "$TMP/repo_hook_ran" ]
}

@test "a failing repo-local hook still blocks the commit through the guard" {
  setup_assigned_repo
  mkdir -p "$REPO/.git/hooks"
  cat > "$REPO/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
echo "repo hook says no" >&2
exit 1
EOF
  chmod +x "$REPO/.git/hooks/pre-commit"

  "$GA" install-hook >/dev/null

  run do_commit "should be blocked"
  [ "$status" -ne 0 ]
  # commit must not have been created
  run git -C "$REPO" rev-parse HEAD
  [ "$status" -ne 0 ]
}

@test "a previously-set global core.hooksPath is preserved and chained" {
  setup_assigned_repo

  # Pre-existing global hooks dir with its own pre-commit.
  prev="$TMP/prevhooks"
  mkdir -p "$prev"
  cat > "$prev/pre-commit" <<EOF
#!/usr/bin/env bash
touch "$TMP/prev_global_ran"
exit 0
EOF
  chmod +x "$prev/pre-commit"
  git config --global core.hooksPath "$prev"

  "$GA" install-hook >/dev/null
  # install-hook should have recorded the previous path
  [ "$(git config -f "$GIT_ACCOUNT_CONFIG_DIR/config" --get hook.previoushookspath)" = "$prev" ]

  run do_commit "chain prev global"
  [ "$status" -eq 0 ]
  [ -f "$TMP/prev_global_ran" ]
}

@test "uninstall-hook restores the previous global core.hooksPath" {
  prev="$TMP/prevhooks"
  mkdir -p "$prev"
  git config --global core.hooksPath "$prev"

  "$GA" install-hook >/dev/null
  [ "$(git config --global --get core.hooksPath)" != "$prev" ]

  "$GA" uninstall-hook >/dev/null
  [ "$(git config --global --get core.hooksPath)" = "$prev" ]
}

@test "uninstall-hook unsets hooksPath when there was none before" {
  "$GA" install-hook >/dev/null
  [ -n "$(git config --global --get core.hooksPath || true)" ]

  "$GA" uninstall-hook >/dev/null
  run git config --global --get core.hooksPath
  [ "$status" -ne 0 ]
}

@test "with no repo hook, the guard alone allows a matching commit" {
  setup_assigned_repo
  "$GA" install-hook >/dev/null

  run do_commit "clean"
  [ "$status" -eq 0 ]
  run git -C "$REPO" rev-parse HEAD
  [ "$status" -eq 0 ]
}

@test "guard blocks a commit whose identity does not match the assigned profile" {
  setup_assigned_repo
  # Sabotage the identity after assignment.
  git -C "$REPO" config user.email wrong@example.com

  "$GA" install-hook >/dev/null

  run do_commit "mismatch"
  [ "$status" -ne 0 ]
  [[ "$output" == *"COMMIT BLOCKED"* ]]
}
