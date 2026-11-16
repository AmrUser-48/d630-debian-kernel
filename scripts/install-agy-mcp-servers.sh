#!/usr/bin/env bash
set -Eeuo pipefail

: "${GH_PAT:?GH_PAT is required for GitHub MCP access}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required for Git MCP}"

BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/d630-runner"
install -d -m 0755 "$BIN_DIR"
install -d -m 0700 "$CONFIG_DIR"

# Keep the PAT readable only by the runner account.
umask 077
printf '%s' "$GH_PAT" > "$CONFIG_DIR/gh-token"
chmod 0600 "$CONFIG_DIR/gh-token"

case "$(uname -m)" in
  x86_64|amd64) RELEASE_ARCH=x86_64 ;;
  aarch64|arm64) RELEASE_ARCH=arm64 ;;
  *)
    echo "::error::Unsupported runner architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

# Pin the official GitHub MCP Server release for reproducible runner setup.
GITHUB_MCP_VERSION=2.1.0
ASSET="github-mcp-server_Linux_${RELEASE_ARCH}.tar.gz"
TMP_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/agy-mcp.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

curl --fail --silent --show-error --location --retry 3 \
  "https://github.com/github/github-mcp-server/releases/download/v${GITHUB_MCP_VERSION}/${ASSET}" \
  --output "$TMP_DIR/$ASSET"
tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR"

GITHUB_MCP_BINARY="$(find "$TMP_DIR" -type f -name github-mcp-server -print -quit)"
[[ -n "$GITHUB_MCP_BINARY" && -s "$GITHUB_MCP_BINARY" ]] || {
  echo "::error::GitHub MCP release archive did not contain github-mcp-server." >&2
  exit 1
}
install -m 0755 "$GITHUB_MCP_BINARY" "$BIN_DIR/github-mcp-server"

# Install uv without changing the runner's PATH globally.
if ! command -v uv >/dev/null 2>&1; then
  curl --fail --silent --show-error --location https://astral.sh/uv/install.sh |
    env UV_INSTALL_DIR="$BIN_DIR" UV_NO_MODIFY_PATH=1 sh
fi
UV_BIN="$(command -v uv || printf '%s/uv' "$BIN_DIR")"
"$UV_BIN" tool install --upgrade mcp-server-git

test -x "$BIN_DIR/github-mcp-server"
test -x "$BIN_DIR/mcp-server-git"
git -C "$GITHUB_WORKSPACE" rev-parse --show-toplevel > "$CONFIG_DIR/git-mcp-repository"
chmod 0600 "$CONFIG_DIR/git-mcp-repository"

# Keep GH_TOKEN available to normal SSH login shells. Agy's GitHub MCP command
# reads the same protected token file as GITHUB_PERSONAL_ACCESS_TOKEN.
if ! grep -Fq 'd630-runner/gh-token' "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'D630_MCP_TOKEN_ENV'
# D630 runner GitHub MCP credentials (token is stored mode 0600).
if [[ -r "$HOME/.config/d630-runner/gh-token" ]]; then
  export GH_TOKEN="$(<"$HOME/.config/d630-runner/gh-token")"
  export GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN"
fi
D630_MCP_TOKEN_ENV
fi

echo "GitHub MCP Server: $("$BIN_DIR/github-mcp-server" --version 2>/dev/null || echo installed)"
echo "Git MCP Server: $("$BIN_DIR/mcp-server-git" --help >/dev/null 2>&1 && echo installed)"
echo "Git MCP repository: $(<"$CONFIG_DIR/git-mcp-repository")"
