# git-account

A dependency-free `git` plugin (plain bash) that remembers **which GitHub account
each repo uses** and applies the right **identity, SSH/HTTPS auth, and commit
signing** automatically — even when several accounts live on the same host
(e.g. a personal and an enterprise account, both on `github.com`).

It works by writing settings into each repo's **local** `.git/config`, so the
choice is remembered inside the repo itself. No special directory layout is
required — clone repos wherever you like.

```
$ git account add work --name "Work Person" --email me@corp.com \
    --host github.com --ssh-key ~/.ssh/id_work
$ git account rule add github.com/acme-corp work   # route this org to 'work'
$ git clone git@github.com:acme-corp/service.git && cd service
$ git account apply            # auto-detects via the rule, or asks once and remembers
git-account: applied profile 'work' (auto-detected from github.com).
```

## How it works

Everything maps onto native git config keys, so "remembering" is free:

| Concern     | What gets set (in repo-local config)                          |
|-------------|---------------------------------------------------------------|
| Identity    | `user.name`, `user.email`                                     |
| SSH auth    | `core.sshCommand = ssh -i <key> -o IdentitiesOnly=yes`        |
| HTTPS auth  | `credential.https://<host>.username` (token stays in keychain)|
| Signing     | `user.signingkey`, `gpg.format`, `commit.gpgsign`, `tag.gpgsign` |
| Marker      | `account.profile` (which profile is active)                   |

Profiles and matching rules are stored in `~/.config/git-account/config`
(read/written via `git config -f`, so no parser is needed).

Auto-detection is **rule-driven**: the account is chosen by matching the repo's
remote `host[/owner]` against the rules you've defined (`git account rule add`).
An owner rule (`github.com/acme-corp`) beats a host rule (`github.com`). If
exactly one rule matches it is applied silently; if several match (e.g. two
accounts both ruled to `github.com`) it prompts once and remembers your choice
as an owner-level rule so it is silent next time; if none match it asks which
account to use. A profile's `host` field is only used to wire up HTTPS
credentials — it is **not** a matcher, so accounts never get force-applied to a
whole host without an explicit rule.

## Installation

All methods below coexist — pick whichever you prefer.

### 1. Homebrew (recommended, macOS/Linux)

From your own tap (a repo named `homebrew-tap` containing `Formula/git-account.rb`):

```bash
brew install achekulaev/tap/git-account
```

Updates come via `brew upgrade`. No review/waiting period — publishing to your
own tap is instant.

### 2. One-line curl installer

```bash
curl -fsSL https://raw.githubusercontent.com/achekulaev/git-account/main/install.sh | bash
```

### 3. From source

```bash
git clone https://github.com/achekulaev/git-account
cd git-account
./install.sh          # symlinks git-account into ~/.local/bin
```

Or install into a prefix with `make`:

```bash
make install PREFIX=/usr/local     # tree -> libexec, symlink -> bin
```

### 4. Single-file drop-in (zero other files)

```bash
make bundle           # writes dist/git-account (self-contained)
cp dist/git-account ~/bin/          # anywhere on PATH
```

> Installing only puts `git-account` on your PATH. The commit **guard hook is
> opt-in** and is never enabled automatically (see below).

## Uninstalling

Removing the binary does **not** remove the state git-account created. In
particular, uninstalling the package does not run any cleanup.

**Only if you enabled the guard hook** (i.e. you ran `git account install-hook`
— it is opt-in and never enabled automatically), disable it first, *while the
binary still exists*:

```bash
git account uninstall-hook
```

This restores or unsets the global `core.hooksPath`. Skipping it when the hook
was enabled leaves git pointing at a hooks directory that no longer exists,
which breaks commits everywhere. If you never ran `install-hook`, skip this step.

Then remove the binary using **one** of these — whichever matches how you
installed:

```bash
# Homebrew:
brew uninstall git-account
```

```bash
# From source with make (match your install PREFIX):
make uninstall PREFIX=/usr/local
```

```bash
# curl installer / ./install.sh / single-file drop-in:
rm -f ~/.local/bin/git-account
```

Finally, remove leftover state that is intentionally **not** touched by any
uninstall step:

```bash
# Profiles and matching rules (safe to delete once you no longer need them):
rm -rf ~/.config/git-account

# Optional: generated SSH keys, if you let the wizard create any:
#   ls ~/.ssh/id_ed25519_*      # inspect first, then remove the ones you want
```

Per-repo settings (`user.name/email`, `core.sshCommand`, `account.profile`,
signing keys) live in each repo's local `.git/config` and are left as-is; they
are harmless without the plugin, but you can clear a repo with
`git config --local --remove-section account` (and unset any keys you no longer
want) if desired.

## Usage

```
git account add [name] [flags]     Create/update a profile (wizard if interactive)
git account list                   List profiles
git account remove <name>          Delete a profile and its rules

git account apply                  Auto-detect the account (prompt if ambiguous)
git account use <name>             Force a specific profile onto this repo
git account whoami                 Show the active profile + effective identity
git account clone [--as <p>] <url> [dir]   Clone using an account's key, then apply it

git account rule add <host[/owner]> <profile>
git account rule remove <host[/owner]> <profile>
git account rule list

git account install-hook           Enable the commit guard (opt-in, global)
git account uninstall-hook         Disable it (restores any previous hooks path)

git account doctor                 Verify keys/config and current repo status
```

`add` flags: `--name --email --host --ssh-key --signing-key
--gpg-format <openpgp|ssh> --sign <true|false> --credential-user`.

### Interactive wizard

Run `git account add` with no (or insufficient) flags and it walks you through
setup, prompting only for what's missing:

```
$ git account add
Account id (e.g. work, personal): work
Full name (e.g. John Smith): John Smith
Email (should match the address you sign in with): john@corp.com
Git host [github.com]:
SSH private key path (Enter = generate a new key, "none" = skip):
git-account: generating a new ed25519 SSH key at ~/.ssh/id_ed25519_work ...
git-account: created SSH key pair:
git-account:   private: ~/.ssh/id_ed25519_work
git-account:   public:  ~/.ssh/id_ed25519_work.pub
git-account: ACTION REQUIRED: add the PUBLIC key to your github.com account:
git-account:   github.com -> Settings -> SSH and GPG keys -> New SSH key -> paste the key below
----------------------------------------------------------------
ssh-ed25519 AAAA... john@corp.com
----------------------------------------------------------------
Use this SSH key to sign commits too? [y/N] y
git-account: saved profile 'work' (john@corp.com).
```

Pressing Enter at the SSH key prompt generates a fresh `ed25519` keypair in
`~/.ssh/` (named after the account id) and wires it up; on a real terminal
`ssh-keygen` will offer to set a passphrase. It then prints the public key file
path and tells you exactly where to paste it (`<host>` -> Settings -> SSH and
GPG keys -> New SSH key). Any field you pass as a flag is not prompted for.

### Same host, two accounts (personal + enterprise on github.com)

```bash
git account add personal --name "Me" --email me@users.noreply.github.com \
  --host github.com --ssh-key ~/.ssh/id_personal
git account add work     --name "Me @ Corp" --email me@corp.com \
  --host github.com --ssh-key ~/.ssh/id_work \
  --signing-key ~/.ssh/id_work.pub --gpg-format ssh --sign true

# Route a specific org to the work account:
git account rule add github.com/acme-corp work
```

Now `git account apply` in any `acme-corp` repo silently selects `work`;
other `github.com` repos prompt once and remember the choice.

### Cloning with the right account

A plain `git clone` authenticates *before* any repo (and thus any repo-local
config) exists, so it uses whatever SSH key/agent or stored token git would
normally pick. `git account clone` fixes this by forcing the chosen profile's
key for just the initial handshake via a one-shot `-c core.sshCommand`, then
pinning the account into the new repo:

```bash
# Auto-detect the account from the URL's host/owner (prompts if ambiguous):
git account clone git@github.com:acme-corp/service.git

# Or force a specific profile (skips detection):
git account clone --as work git@github.com:acme-corp/service.git
```

Because the forced key uses `IdentitiesOnly=yes`, this works even when a
personal and enterprise account share `github.com` — no `~/.ssh/config` host
alias is required. After cloning, the profile's identity, auth, and signing are
written to the repo's local config (via `use`/`apply`) for all later commits and
pushes. HTTPS clones still prompt for a token if one isn't already stored; only
the credential *username* hint can be pre-seeded.

## The guard hook (opt-in)

`git account install-hook` sets the **global** `core.hooksPath` to this plugin's
`hooks/` directory. From then on, before every commit in any repo, the guard:

1. Blocks the commit if the repo is assigned a profile but `user.email` does not
   match it (preventing "committed with the wrong account" mistakes).
2. Auto-applies a confidently-detected profile for repos that don't have one yet.
3. **Chains** to any repo-local `.git/hooks/pre-commit` and to any global hooks
   path that was configured before, so existing hooks are never skipped.

Because `core.hooksPath` is global and overrides per-repo hooks, this is strictly
opt-in and reversible with `git account uninstall-hook`.

## Native alternative

If you only need identity switching (no bundled auth/signing or guard), git 2.36+
can do it natively via conditional includes in `~/.gitconfig`:

```ini
[includeIf "hasconfig:remote.*.url:git@github-work:*/**"]
    path = ~/.gitconfig-work
```

`git-account` adds interactive setup, auth + signing bundling, location
independence, and the mistake-preventing guard hook on top of these primitives.

## Development

```bash
make test      # run the bats suite (requires bats-core)
make lint      # shellcheck (if installed)
make bundle    # build the single-file distribution
```

Tests run each case in an isolated `HOME` and config dir, so your real git
configuration is never touched. `tests/hook_chaining.bats` specifically proves
the guard hook chains to repo-local and previously-configured global hooks.

## License

MIT
