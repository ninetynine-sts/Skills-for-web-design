#!/bin/bash
# Preinstall the impeccable engine binary so the skill works without network
# access to github.com release assets.
#
# Why this exists: .agents/skills/impeccable/scripts/impeccable shells out to a
# compiled engine. Its last-resort fallback downloads that engine from
# github.com/pbakaus/impeccable/releases, which some sandboxes block (HTTP 403).
# Without an engine the skill still loads but degrades to its "launcher
# unavailable" path, losing context loading, screenshots, the live browser and
# the edit hooks.
#
# npm serves the same engine as per-platform packages and is reachable where
# release assets are not, so fetch from there and verify against the sha512
# that npm publishes in dist.integrity. Fails closed: no verification, no
# install. Never commits a binary to the repo.
set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
skill="$root/.agents/skills/impeccable"
[ -d "$skill" ] || exit 0

ver=$(tr -d '[:space:]' < "$skill/scripts/VERSION" 2>/dev/null || true)
[ -n "$ver" ] || { echo "impeccable-engine: no scripts/VERSION; skipping" >&2; exit 0; }

case "$(uname -s)" in
  Linux)  os=linux ;;
  Darwin) os=darwin ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT) os=windows ;;
  *) echo "impeccable-engine: unsupported OS $(uname -s); skipping" >&2; exit 0 ;;
esac
case "$(uname -m)" in
  x86_64|amd64)   arch=x64 ;;
  arm64|aarch64)  arch=arm64 ;;
  *) echo "impeccable-engine: unsupported arch $(uname -m); skipping" >&2; exit 0 ;;
esac

dest="$skill/scripts/bin/$os-$arch"
bin="$dest/impeccable"
[ "$os" = windows ] && bin="$bin.exe"

# Idempotent: a working engine of the right version is left alone.
if [ -x "$bin" ] && [ "$(IMPECCABLE_LAUNCHER_PROBE=1 "$bin" engine-probe 2>/dev/null || true)" = "impeccable-engine $ver" ]; then
  echo "impeccable-engine $ver already present"
  exit 0
fi

command -v npm >/dev/null 2>&1 || { echo "impeccable-engine: npm not found; skipping" >&2; exit 0; }

pkg="@impeccable/cli-$os-$arch"
integrity=$(npm view "$pkg@$ver" dist.integrity 2>/dev/null | tr -d "'\" " || true)
tarball=$(npm view "$pkg@$ver" dist.tarball 2>/dev/null | tr -d "'\" " || true)
if [ -z "$integrity" ] || [ -z "$tarball" ]; then
  echo "impeccable-engine: no npm metadata for $pkg@$ver; skipping (skill degrades gracefully)" >&2
  exit 0
fi

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
if ! curl -fsSL --retry 2 -o "$tmp/pkg.tgz" "$tarball"; then
  echo "impeccable-engine: download failed for $pkg@$ver; skipping" >&2
  exit 0
fi

# Fail closed on verification, exactly as the vendor's launcher does.
alg=${integrity%%-*}
want=${integrity#*-}
case "$alg" in
  sha512) got=$(openssl dgst -sha512 -binary "$tmp/pkg.tgz" | openssl base64 -A) ;;
  sha256) got=$(openssl dgst -sha256 -binary "$tmp/pkg.tgz" | openssl base64 -A) ;;
  *) echo "impeccable-engine: unknown integrity algorithm '$alg'; refusing" >&2; exit 0 ;;
esac
if [ "$got" != "$want" ]; then
  echo "impeccable-engine: integrity mismatch for $pkg@$ver; refusing the download" >&2
  exit 0
fi

tar -xzf "$tmp/pkg.tgz" -C "$tmp" package/bin/ 2>/dev/null || {
  echo "impeccable-engine: no bin/ in $pkg@$ver; skipping" >&2; exit 0; }
src=$(find "$tmp/package/bin" -type f | head -1)
[ -n "$src" ] || { echo "impeccable-engine: empty bin/; skipping" >&2; exit 0; }

mkdir -p "$dest"
cp "$src" "$bin"
chmod +x "$bin"
echo "impeccable-engine $ver installed from $pkg ($alg verified)"
