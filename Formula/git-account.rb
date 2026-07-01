# Homebrew formula for git-account.
#
# Ship this from your own tap (a repo named homebrew-tap):
#   brew install achekulaev/tap/git-account
#
# Update `url` and `sha256` on each release (git tag -> GitHub tarball).
class GitAccount < Formula
  desc "Per-repo GitHub account switcher (identity + auth + signing)"
  homepage "https://github.com/achekulaev/git-account"
  url "https://github.com/achekulaev/git-account/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "d6c04ed17801bcba9d4625d796dbf6b42a51785ee041c49e154c75c793830124"
  license "MIT"
  version "0.1.0"

  depends_on "git"

  def install
    # Install the whole tree into libexec and expose the entrypoint on PATH.
    libexec.install "git-account", "lib", "hooks"
    (libexec/"git-account").chmod 0755
    (libexec/"hooks/pre-commit").chmod 0755
    bin.install_symlink libexec/"git-account"
  end

  test do
    assert_match "git-account", shell_output("#{bin}/git-account version")
  end
end
