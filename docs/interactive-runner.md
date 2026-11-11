# Interactive build runner

The `D630 Interactive Build Runner` workflow creates a temporary Ubuntu 24.04 VM. SSH listens only on the runner's Tailscale IPv4 address. The workflow is manual-only and has a six-hour job limit.

## Repository secrets

Configure these GitHub Actions repository secrets in `AmrUser-48/d630-debian-kernel`:

- `SSH_PUBLIC_KEY`: the public half of `~/.ssh/id_ed25519_macos_runner`. The private key stays on the client.
- `TAILSCALE_AUTHKEY`: a Tailscale auth key accepted by the tailnet. The workflow passes it to `tailscale/github-action@v4`.
- `DESKTOP_COMMANDER_DEVICE_B64`: a base64-encoded gzip archive containing the Remote Device session and MQTT credentials. The runner restores it into `~/.desktop-commander-device`.
- `GH_PAT`: a fine-grained personal access token used by GitHub CLI and Git credential setup on the interactive runner. It replaces the limited workflow `GITHUB_TOKEN` for `gh`/Git operations.

Create this secret from the machine that already has the authenticated `~/.desktop-commander-device` directory. Only the three credential files are archived; diagnostic logs are deliberately excluded:

```bash
tar -C "$HOME" -czf - \
  .desktop-commander-device/device.json \
  .desktop-commander-device/.mqtt/identity.json \
  .desktop-commander-device/.mqtt/certificate.json \
  | base64 -w0 \
  | gh secret set DESKTOP_COMMANDER_DEVICE_B64 -R AmrUser-48/d630-debian-kernel
```

Check secret names, not values, with:

```bash
gh secret list -R AmrUser-48/d630-debian-kernel
```

### Create the runner GitHub token

Create a fine-grained PAT at <https://github.com/settings/personal-access-tokens/new>:

1. Set **Resource owner** to `AmrUser-48`.
2. Set **Repository access** to **All repositories**.
3. Give the repositories the permissions the runner must administer. For broad repository management, enable read/write for **Administration, Actions, Contents, Deployments, Environments, Issues, Pull requests, Secrets, Variables, Webhooks, Checks, Commit statuses, Discussions, and Workflows** where offered. Keep **Metadata** at read-only.
4. Set an expiration compatible with your account policy. Rotate the token before it expires.

Then add it without putting the token in shell history:

```bash
gh secret set GH_PAT -R AmrUser-48/d630-debian-kernel
```

The interactive workflow uses `GH_PAT` to authenticate `gh` and configure Git credential access. The token is stored in the runner user's GitHub CLI credential file, so processes running as `runner` (including Desktop Commander Remote) can use that access. This is intentionally powerful: a compromised process on the runner could modify or delete any repository granted to the token. Limit the token to the repositories you actually want managed, and cancel the runner when finished. The workflow's built-in `GITHUB_TOKEN` remains separately restricted by its declared `permissions`.

The client machine must be logged into the same tailnet. The tailnet ACL must allow the client to reach `tag:d630-runner` over TCP 22 and the UDP ports used by Mosh (default range 60000–61000). Do not expose SSH on the public interface.

Set the secrets with GitHub CLI:

```bash
gh secret set SSH_PUBLIC_KEY -R AmrUser-48/d630-debian-kernel < ~/.ssh/id_ed25519_macos_runner.pub
gh secret set TAILSCALE_AUTHKEY -R AmrUser-48/d630-debian-kernel
```

The second command prompts for the auth-key value. Check names, not values, with:

```bash
gh secret list -R AmrUser-48/d630-debian-kernel
```

## Start and connect

Run the workflow from the D630 client with the `deb-runner` shell function, or dispatch **D630 Interactive Build Runner** manually from the repository's Actions page. The function waits for the new runner to join Tailscale, verifies SSH access with the configured private key, writes the Mosh reconnect command to `~/.deb-runner`, and starts Mosh.

Reconnect to an existing runner with:

```bash
~/.deb-runner
```

The client function must not use `exec "$HOME/.deb-runner"`; invoke the script as a child so disconnecting from Mosh returns to the local shell.

The workflow log prints the runner's Tailscale hostname, IPv4 address, and SSH host-key fingerprint. The runner is ephemeral; cancel the workflow to terminate it, or let the six-hour limit expire.

## Desktop Commander Remote MCP

The runner uses the `@wonderwhy-er/desktop-commander` npm package. The workflow sets up Node.js 24, restores the saved device credentials, installs the package, and starts `desktop-commander remote` in the background. The process remains available while the interactive workflow is running.

This is the **Desktop Commander Remote Device** process, not a separate MCP server hosted by GitHub. It connects the runner to the Desktop Commander Remote MCP service; tool execution occurs locally as the `runner` account. The persisted credentials allow restarts without repeating browser pairing. Keep the `DESKTOP_COMMANDER_DEVICE_B64` secret private.

## Installed user configuration

The workflow fetches the Debian-specific configuration repository `AmrUser-48/deb12dots` at runtime. It installs these user files into the runner account:

- Bash: `.bashrc`, `.aaliases`, and `.inputrc`.
- Neovim: the complete `.config/nvim` directory, including its vendored plugins and themes.
- lf: `.config/lf/lfrc`, `icons`, and `colors`.
- bat: `.config/bat/config`.
- Command timer: `bash-command-timer/bash_command_timer.sh`, installed at the path expected by the Bash configuration.

The workflow also creates `~/.config/d630-runner/env`. It sets the workspace to the checked-out `d630-debian-kernel` repository, puts `~/.local/bin` first on `PATH`, sets `OPENER=xdg-open`, and configures Core 2 build settings: `ARCH=x86_64`, `KCFLAGS=-march=core2 -mtune=core2`, and `BUILD_JOBS`/`MAKEFLAGS` from the hosted runner's CPU count. The user's Bash configuration sources this environment.

The runner setup installs `fd` as a symlink to Debian's `fdfind`, and `bat` as a symlink to `batcat`. It validates the shell scripts and starts Neovim headlessly before proceeding to Tailscale/SSH setup. Two invalid lf config lines are corrected only in the runner copy; the source `deb12dots` repository is not modified.

The runner also installs Neovim, lf, ripgrep, fzf, tmux, htop, jq, tree, Mosh, OpenSSH, and the D630 kernel build prerequisites. Vim packages are removed; Neovim provides the editor.

## D630 firmware checks

Before exposing the session, the workflow checks for the Intel 3945ABG firmware and the T7250 microcode file `intel-ucode/06-0f-0d`, then validates CPUID signature `0x000006fd`. The wireless firmware is decompressed directly to the kernel-requested path when the package supplies a `.zst` file. The installed microcode is checked in place.

## Build workflow distinction

This is a native Ubuntu interactive environment. Use `BUILD-UBUNTU.md` for the direct Ubuntu `make bindeb-pkg` route. The existing `d630-kernel-build.yml` remains separate: it builds in Debian Bookworm and performs the repository's audit and release process.
