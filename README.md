# git identity

One signing key and one GitHub token **per repository clone**. Nothing global. If a key or token
leaks, you revoke that one and nothing else is affected.

Tool: `git-identity` (installed as `~/.local/bin/git-identity`, run as `git identity ...` from inside a clone).
Quick reference: `git identity help`.

## Install

One line, on any Mac or Linux machine with curl (wget works too):

```bash
curl -fsSL https://raw.githubusercontent.com/masterde/git-identity/main/install.sh | bash
```

It puts `git-identity` and `git-identity-keygen` into `~/.local/bin` and tells you if that
directory is not on your PATH. From a clone of this repo, `./install.sh` does the same from the
checked-out files. A machine that already has the tool can push it to another one over SSH:

```bash
git identity install user@host
```

Mac only: install [Secretive](https://github.com/maxgoedjen/secretive) for Secure Enclave keys
(`brew install --cask secretive`). Without it the tool uses key files, as on Linux.

---

## 1. The idea in one minute

Every clone gets two things, bound to that clone only (stored in its `.git/config`):

| Thing | What it is for | Where it lives |
|---|---|---|
| **Signing key** | Signs every commit and tag, so GitHub shows *Verified* and rulesets that require signatures let the PR merge | Secretive (Secure Enclave) on a Mac that has it; otherwise a key file |
| **Token** | Lets `git fetch/push` (and `gh`) talk to GitHub for that one repo | login Keychain on a Mac with Secretive; otherwise a 0600 file |

Two **profiles** decide who the clone belongs to:

| Profile | Key name | Key protection (Secretive) | Token entry |
|---|---|---|---|
| `--me` | `<owner>-<repo>` | Require Authentication (Touch ID per commit) | `github.com/<owner>/<repo>` |
| `--agent` | `agent-<owner>-<repo>` | Notify (no Touch ID, a notification per use, so the agent runs unattended) | `github.com/<owner>/<repo>@agent` |

Two **modes**, picked automatically, same commands either way:

| Mode | When | Keys | Tokens |
|---|---|---|---|
| `secretive` | a Mac where Secretive's agent is running | Secretive, by name | login Keychain, service `git-identity` |
| `file` | Linux, or any Mac without Secretive (headless, no Touch ID) | `~/.ssh/identities/<name>` (ed25519, no passphrase, 0600) | `~/.config/git-identity/tokens/<account>` (0600) |

Force a mode with `GIT_IDENTITY_MODE=secretive` or `=file` if the guess is wrong.

House rules the tool follows:

- never `gh auth login`; tokens are fine-grained, one repo (or one owner) each, 30 to 90 days
- no global signing key. A clone that has not been set up refuses to commit with
  *"either user.signingkey or gpg.ssh.defaultKeyCommand needs to be configured"*.
  That error means: run `git identity` in that clone.
- the tool never prints a token to a terminal; `git identity token` works only inside a pipe or `$(...)`

---

## 2. The process, every time

```bash
cd <clone>
git identity --agent --email you@example.com     # or --me
```

| Step | What happens | What you do |
|---|---|---|
| 1 key | **secretive mode:** Secretive opens; the tool waits (up to 15 min) for a key with the exact name. **file mode:** the key is generated at once. | Secretive: click **+**, type the Name shown, pick the Protection shown. Then register the public key on GitHub: it is on the clipboard (Mac) or printed (Linux); the page `github.com/settings/ssh/new` opens or is printed. Key type: **Signing Key**. Title: the key name. |
| 2 token | The tool prints the exact token settings and opens `github.com/settings/personal-access-tokens/new`. | Create the token with those settings, copy it, paste it at the prompt (in a terminal) or into the hidden dialog (from Claude Code). Nothing is echoed. |
| 3 check | `git fetch` with the token, then an empty signed commit which is removed again. | Read the two results. |

Then `git identity show` tells you what the clone is bound to, at any time.

The email you pass must be verified on the GitHub account that holds the key, or commits show
*Unverified* even though they are signed.

---

## 3. Situations

### A new clone for my own work on this Mac

```bash
git identity --me --email you@example.com
```

Key protection Require Authentication: Touch ID on every commit. Token entry `github.com/<owner>/<repo>`.

### A new clone an agent will work in, on this Mac

```bash
git identity --agent --email you@example.com
```

Key protection **Notify**: no Touch ID, so the agent can commit unattended; you get a notification
per signature. Token entry ends in `@agent`, so the agent's token and yours never mix even for the same repo.

### Running it from inside Claude Code (no terminal)

Works the same. Differences: the tool does not wait for Enter after the key step, and the token is
taken through a hidden macOS dialog instead of a terminal prompt. If the dialog does not appear,
open a Terminal tab in that clone and run `git identity set --token`.

### A Linux machine, or a Mac you cannot reach that has no Touch ID

From a machine that has the tool, once per target machine:

```bash
git identity install root@linux-box          # or user@other-mac
```

Copies the tool (and, for a Mac, the signing wrapper). Then, over SSH, in the agent's clone:

```bash
git identity --agent --email you@example.com
```

File mode: the key is generated as a file, its public half is printed for you to register on GitHub,
the token is asked for at the prompt. Run it as the OS user the agent runs as, so only that user can
read the key and token. Without a terminal there, supply the token through the environment:

```bash
read -rs GIT_IDENTITY_TOKEN && export GIT_IDENTITY_TOKEN && git identity --agent --email you@example.com; unset GIT_IDENTITY_TOKEN
```

Afterwards remove any broad token left on that machine (for example `~/.config/gh/hosts.yml`) and delete it on GitHub.

### A second Mac that has Touch ID

Same install command, then the normal wizard there. Secretive keys cannot leave the Secure Enclave and
the Keychain does not sync these items, so that Mac gets its own key per repo, each registered on
GitHub separately. That is intended: losing a machine means revoking that machine's keys and tokens only.

### Two clones of the same repo on the same machine

The key already exists, so the wizard says *already exists, reusing it*; the token entry is found
and reused too. Or bind by hand:

```bash
git identity set --as agent --email you@example.com --sign agent-<owner>-<repo> --token
```

### Several repos of one owner should share one token

Create a fine-grained token scoped to those repos, then in any one of the clones:

```bash
git identity set --token --owner
```

The entry is `github.com/<owner>[@profile]`. Lookup order is always repo entry first, then owner entry.

### The token expired or you want to rotate it

Regenerate on GitHub (`github.com/settings/personal-access-tokens`), then:

```bash
git identity set --token --replace            # add --owner for an owner-wide entry
```

### A machine is lost, an agent misbehaved, or a key or token may have leaked

1. GitHub, *Settings, SSH and GPG keys*: delete that key (by its name).
2. GitHub, *Settings, Personal access tokens*: delete that token (by its name).
3. On the machine, if you still have it: `git identity forget` (or `forget --owner`), and delete the
   key in Secretive or under `~/.ssh/identities/`.

Nothing else needs touching; every other clone keeps working.

### Using the repo's token with gh or curl

```bash
GH_TOKEN="$(git identity token)" gh pr list
GH_TOKEN="$(git identity token)" gh pr view 174
```

`git identity token` refuses to print to a terminal, so the value never lands in scrollback.

### Seeing what a clone is set up with

```bash
git identity show        # key, email, profile, token entry (never the token itself)
git identity list        # every stored token entry on this machine, names only
```

### Commits show "Unverified", or a PR says it needs signed commits

Check in this order:

1. **Is the key registered on GitHub as a Signing Key?** `git identity show` names the key;
   compare with *Settings, SSH and GPG keys*. If missing: `ssh-add -L` (Mac) or
   `cat ~/.ssh/identities/<name>.pub` (file mode) and add it.
2. **Is the commit email verified on that GitHub account?** `git identity show` prints it.
3. **Were the commits made before the clone was set up?** Then they are simply unsigned.
   Replay them signed and push with a lease (rewrites that branch's history):

   ```bash
   git rebase origin/main --exec 'git commit --amend --no-edit -S'
   git push --force-with-lease
   ```

   Or recreate the branch from a fresh, set-up clone.

### "either user.signingkey or gpg.ssh.defaultKeyCommand needs to be configured"

The clone has never been set up. Run `git identity` in it. (Deliberate: there is no global key.)

### The agent gets a Touch ID prompt and stalls

Its key was created with Require Authentication. In Secretive, delete the key and recreate it with
the same name and **Notify**, or create a new one and `git identity set --sign <new-name>`.

### "no token for github.com/..." although you stored one

- `git identity show` prints the account name it looks for; `git identity list` prints what exists.
  Profiles matter: `...@agent` and `...` are different entries.
- On a Mac, make sure it is in Secretive mode: `GIT_IDENTITY_MODE=secretive git identity list`.
  If that finds it, Secretive's agent was not running (open Secretive once).
- Over SSH to a Mac the login Keychain may be locked; file mode is the right choice there.

### Secretive is not running, or the key says "not in agent"

Open Secretive once. The tool and the signing wrapper always talk to Secretive's own socket, so it
works even inside Claude Code sessions that have no `SSH_AUTH_SOCK`.

### Cloning the repo again elsewhere

Nothing is portable, by design. Run `git identity` in the new clone; keys and token entries
already on that machine are reused, missing ones are created.

---

## 4. Reference

**Commands**

```
git identity                         wizard (asks me/agent, then email if unknown)
git identity --me | --agent [--email <e>]
git identity set [--sign <key>] [--token [--owner] [--replace]] [--email <e>] [--as <profile>]
git identity show | list | token | forget [--owner]
git identity install [user@]host
git identity help
```

**What the wizard writes into the clone's `.git/config`**

```
identity.profile          me | agent
user.email                <email>
gpg.format                ssh
user.signingkey           key::<public key>                 (secretive)   |  ~/.ssh/identities/<name>  (file)
gpg.ssh.program           ~/.local/bin/git-identity-keygen  (secretive only; routes signing to Secretive)
commit.gpgsign / tag.gpgsign   true
credential.helper         !git-identity cred      credential.useHttpPath true
```

plus a line in `~/.gitallowedsigners` so `git log --show-signature` can verify locally.

**GitHub pages**

- Signing keys: https://github.com/settings/ssh/new (type **Signing Key**)
- Tokens: https://github.com/settings/personal-access-tokens/new
  - Resource owner: the org or user that owns the repo
  - Repository access: *Only select repositories*, then that repo
  - Permissions: Contents **Read and write**; Pull requests **Read and write** if the agent opens PRs
  - Expiration: 30 to 90 days

**Files on disk**

| | secretive mode | file mode |
|---|---|---|
| private keys | Secure Enclave (not a file) | `~/.ssh/identities/<name>` 0600 |
| tokens | login Keychain, service `git-identity` | `~/.config/git-identity/tokens/<account>` 0600 |
| allowed signers | `~/.gitallowedsigners` | `~/.gitallowedsigners` |
| the tool | `~/.local/bin/git-identity`, `~/.local/bin/git-identity-keygen` | `~/.local/bin/git-identity` |

**Environment**

- `GIT_IDENTITY_TOKEN` supplies a token without a prompt (unset it afterwards)
- `GIT_IDENTITY_MODE=secretive|file` overrides mode detection

**Never**

- `gh auth login`, classic tokens, or a token with access to all repos
- a global `user.signingkey`
- copying a private key file or a token between machines
