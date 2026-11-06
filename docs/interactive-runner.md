# Interactive build runner

The `D630 Interactive Build Runner` workflow creates a temporary Ubuntu 24.04 VM and exposes its SSH service only on the Tailscale interface. It does not modify the normal kernel build/release workflow.

## One-time setup

### 1. SSH key

On the D630, create a dedicated key pair:

```bash
ssh-keygen -t ed25519 -a 64 -f ~/.ssh/d630-runner
```

Add the contents of `~/.ssh/d630-runner.pub` as repository secret `SSH_PUBLIC_KEY`. Keep the private key on the D630; never upload it.

### 2. Tailscale workload identity

Configure a Tailscale GitHub workload identity federation for this repository. It must have the `auth_keys` scope. Add these GitHub repository secrets:

- `TS_OAUTH_CLIENT_ID`
- `TS_AUDIENCE`

Create the tag `tag:d630-runner` in the tailnet policy and allow the federated identity to create ephemeral nodes with that tag. The action uses OIDC federation rather than a reusable long-lived auth key. Tailscale removes the ephemeral node after the job ends.

A restrictive policy fragment is:

```json
{
  "tagOwners": {
    "tag:d630-runner": ["autogroup:admin"]
  },
  "grants": [
    {
      "src": ["YOUR-TAILSCALE-USER-IDENTITY"],
      "dst": ["tag:d630-runner"],
      "ip": ["tcp:22", "udp:60000-61000"]
    }
  ]
}
```

Replace `YOUR-TAILSCALE-USER-IDENTITY` with the exact user identity used by the D630. Do not grant access to every tailnet member unless that is intentional. Merge this fragment into the existing policy; do not replace the rest of the policy.

### 3. Start a session

Open **Actions → D630 Interactive Build Runner → Run workflow**. Select the branch containing this workflow. The job is manually triggered and has a six-hour maximum lifetime.

The log prints the Tailscale IPv4 address and the SSH host-key fingerprint. Connect using the private key:

```bash
ssh -i ~/.ssh/d630-runner \
  -o ServerAliveInterval=20 \
  -o ServerAliveCountMax=3 \
  runner@TAILSCALE_IPV4
```

The host key is generated for that ephemeral VM, so verify the fingerprint printed in the workflow log on first connection.

## Low-latency terminal

Install Mosh on the D630:

```bash
sudo apt install mosh
```

Then connect:

```bash
mosh --ssh="ssh -i ~/.ssh/d630-runner" runner@TAILSCALE_IPV4
```

Mosh authenticates through SSH and then carries the interactive terminal over UDP. Its local echo makes typing responsive when round-trip latency is noticeable. Tailscale policy must allow UDP ports `60000-61000` from the D630 to `tag:d630-runner`. Use ordinary SSH for TCP forwarding, SFTP, and other non-interactive SSH features; Mosh does not provide those features.

For a terminal that survives temporary SSH/Mosh disconnects, start:

```bash
tmux new -As d630
```

Cancel the workflow run to terminate the VM. The runner and its local files are ephemeral.

## Included environment

- `git` and `gh`; GitHub CLI is authenticated with a job-scoped `GITHUB_TOKEN` limited to this repository.
- `lf`, `fd` (`fdfind` package), Neovim, ripgrep, fzf, tmux, htop, jq, tree, and bat.
- Mosh and OpenSSH server. Password authentication is disabled; SSH listens only on the Tailscale IPv4 address.
- Native Ubuntu kernel build prerequisites from `BUILD-UBUNTU.md`. The GitHub image already supplies GCC/Make, Git/GH, Bison, Flex, OpenSSL headers, rsync, dpkg tools, zstd, xz, and LZ4; the workflow adds only the missing build libraries/tools, SSH/Mosh, and the CLI environment.
- Intel microcode and Intel wireless firmware packages for the D630 build inputs.

Vim packages are purged. The `vi` and `vim` shell aliases invoke Neovim; there is no Vim executable.

The Bash profile sets `ARCH=x86_64`, defaults `KCFLAGS` to `-march=core2 -mtune=core2`, and sets both `BUILD_JOBS` and GNU Make's default parallelism to the hosted VM's `nproc`. This separates target CPU tuning from build parallelism: generated kernel code targets the T7250/Core 2, while compilation uses the hosted runner's available CPUs. The public-repository Ubuntu 24.04 standard runner currently provides 4 vCPUs and 16 GB RAM.

## Build workflow distinction

The existing `d630-kernel-build.yml` remains unchanged. It builds in a Debian Bookworm container and performs the repository's full audit and release process.

The interactive runner is a native Ubuntu environment. Use `BUILD-UBUNTU.md` for the direct `make bindeb-pkg` route. The current CI script installs its dependencies inside its Debian container, so installing Ubuntu host packages does not pre-populate that container's package database.
