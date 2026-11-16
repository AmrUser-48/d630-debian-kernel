#!/usr/bin/env bash
set -Eeuo pipefail

: "${SSH_PUBLIC_KEY:?SSH_PUBLIC_KEY repository secret is required}"
TAILSCALE_IP="$(tailscale ip -4 | awk '/^100[.]/ { print; exit }')"
[[ "$TAILSCALE_IP" =~ ^100[.] ]] || {
  echo "::error::Tailscale did not provide a private IPv4 address." >&2
  exit 1
}

sudo apt-get update
sudo apt-get install --yes --no-install-recommends openssh-server

install -d -m 0700 "$HOME/.ssh"
printf '%s\n' "$SSH_PUBLIC_KEY" > "$HOME/.ssh/authorized_keys"
chmod 0600 "$HOME/.ssh/authorized_keys"
ssh-keygen -lf "$HOME/.ssh/authorized_keys" >/dev/null
touch "$HOME/.hushlogin"

sudo install -d -m 0755 /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/60-agy-mcp.conf >/dev/null <<EOF
Port 22
ListenAddress $TAILSCALE_IP
PubkeyAuthentication yes
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers runner
PermitTTY yes
AllowTcpForwarding yes
X11Forwarding no
PermitTunnel no
Compression no
PermitUserRC no
PrintMotd no
PrintLastLog no
Banner none
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 6
MaxSessions 12
EOF

# Ubuntu PAM MOTD can write text to SSH stdout despite PrintMotd=no.
# That would corrupt MCP's JSON-RPC stdio stream.
sudo sed -i -E '/^[[:space:]]*[^#].*pam_motd[.]so/s/^/# D630 MCP stdio: disabled PAM MOTD: /' /etc/pam.d/sshd
if grep -Eq '^[[:space:]]*[^#].*pam_motd[.]so' /etc/pam.d/sshd; then
  echo "::error::An active pam_motd hook remains in /etc/pam.d/sshd." >&2
  exit 1
fi

sudo ssh-keygen -A
sudo systemctl disable --now ssh.socket ssh.service 2>/dev/null || true
sudo pkill -x sshd 2>/dev/null || true
sleep 1
sudo rm -f /run/sshd.pid
if pgrep -x sshd >/dev/null; then
  echo "::error::A previous sshd process is still running." >&2
  pgrep -a -x sshd || true
  exit 1
fi

sudo tee /etc/systemd/system/d630-sshd.service >/dev/null <<'D630_SSHD_UNIT'
[Unit]
Description=D630 Tailscale SSH transport for Agy MCP
Wants=network-online.target tailscaled.service
After=network-online.target tailscaled.service
StartLimitIntervalSec=0

[Service]
Type=simple
RuntimeDirectory=sshd
RuntimeDirectoryMode=0755
ExecStartPre=/usr/sbin/sshd -t
ExecStart=/usr/sbin/sshd -D -e
Restart=always
RestartSec=2s
KillSignal=SIGTERM
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
D630_SSHD_UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now d630-sshd.service

for attempt in {1..20}; do
  if sudo systemctl is-active --quiet d630-sshd.service &&
     sudo ss -H -ltnp 'sport = :22' | grep -Fq "$TAILSCALE_IP:22"; then
    break
  fi
  sleep 1
done

LISTENERS="$(sudo ss -H -ltnp 'sport = :22' || true)"
if ! sudo systemctl is-active --quiet d630-sshd.service ||
   ! grep -Fq "$TAILSCALE_IP:22" <<<"$LISTENERS"; then
  echo "::error::sshd did not bind to $TAILSCALE_IP:22." >&2
  sudo systemctl status d630-sshd.service --no-pager || true
  sudo journalctl -u d630-sshd.service -n 60 --no-pager || true
  exit 1
fi

# The remote command shell must not add startup text to MCP stdout.
STARTUP_STDOUT="$(bash --noprofile -c 'source "$HOME/.bashrc"; printf "__D630_CLEAN_STDOUT__"')"
if [[ "$STARTUP_STDOUT" != "__D630_CLEAN_STDOUT__" ]]; then
  echo "::error::Non-interactive Bash startup polluted stdout." >&2
  exit 1
fi

echo "Agy MCP SSH ready: runner@$TAILSCALE_IP"
echo "GitHub MCP: $HOME/.local/bin/github-mcp-server stdio --toolsets all"
echo "Git MCP: $HOME/.local/bin/mcp-server-git --repository $(<"$HOME/.config/d630-runner/git-mcp-repository")"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo
    echo "## Agy MCP access"
    echo "- SSH host: runner@$TAILSCALE_IP"
    echo "- GitHub MCP: installed with all toolsets and write-capable tools"
    echo "- Git MCP repository: $(<"$HOME/.config/d630-runner/git-mcp-repository")"
  } >> "$GITHUB_STEP_SUMMARY"
fi
echo "SSH fingerprint:"
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
