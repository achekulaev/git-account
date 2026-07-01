# Shared setup for bats tests. Each test gets an isolated HOME and config dir,
# so nothing touches the developer's real git / global config.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  GA="$REPO_ROOT/git-account"

  TMP="$(mktemp -d "${BATS_TMPDIR:-/tmp}/ga.XXXXXX")"
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  export GIT_ACCOUNT_CONFIG_DIR="$TMP/gaconf"
  export NO_COLOR=1

  # Isolate git global config to this temp HOME.
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  git config --global user.name "Default" >/dev/null 2>&1 || true
  git config --global user.email "default@example.com" >/dev/null 2>&1 || true
  git config --global init.defaultBranch main >/dev/null 2>&1 || true
  git config --global commit.gpgsign false >/dev/null 2>&1 || true
}

teardown() {
  [ -n "${TMP:-}" ] && rm -rf "$TMP"
}

# Create a repo under $TMP and echo its path.
make_repo() {
  local name="${1:-repo}" url="${2:-}"
  local dir="$TMP/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "default@example.com"
  git -C "$dir" config user.name "Default"
  git -C "$dir" config commit.gpgsign false
  [ -n "$url" ] && git -C "$dir" remote add origin "$url"
  printf '%s\n' "$dir"
}

add_two_profiles() {
  "$GA" add personal --name "Perso Nal" --email personal@example.com --host github.com >/dev/null
  "$GA" add work --name "Work Person" --email work@enterprise.com --host github.com >/dev/null
}
