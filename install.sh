#!/usr/bin/env bash
#
# Install git-account from a source checkout by symlinking the entrypoint onto
# your PATH. This does NOT enable the guard hook (that is opt-in via
# `git account install-hook`) and never touches your global git config.
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
bin_dir="${GIT_ACCOUNT_BIN_DIR:-$HOME/.local/bin}"

mkdir -p "$bin_dir"
ln -sf "$src_dir/git-account" "$bin_dir/git-account"

echo "git-account: linked $bin_dir/git-account -> $src_dir/git-account"

case ":$PATH:" in
  *":$bin_dir:"*) : ;;
  *)
    echo "git-account: NOTE $bin_dir is not on your PATH."
    echo "  Add this to your shell profile:"
    echo "    export PATH=\"$bin_dir:\$PATH\""
    ;;
esac

echo "git-account: installed. Try: git account help"
echo "git-account: to enable the commit guard later: git account install-hook"
