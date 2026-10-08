#!/bin/bash
# Session bootstrap for this skills repo. Two independent jobs, neither fatal:
#
#   1. install_engine     -- the compiled engine the `impeccable` skill shells
#                            out to, fetched from npm and hash-verified.
#   2. install_user_skills -- cross-project skills that live in ~/.claude/skills,
#                            re-cloned because that directory is ephemeral in a
#                            cloud container.
#
# Each job is a function that RETURNS rather than exits, so an early bail in one
# never skips the other. The script always exits 0: a missing skill or engine
# should degrade behavior, never block the session from starting.
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

# --------------------------------------------------------------------------
# 1. impeccable engine
#
# The launcher's own fallback downloads this from github.com release assets,
# which some sandboxes block (HTTP 403). npm serves the same engine as
# per-platform packages and is reachable there, so fetch from npm and verify
# against the sha512 published in dist.integrity. Fails closed on mismatch.
# --------------------------------------------------------------------------
install_engine() {
  local skill="$root/.agents/skills/impeccable"
  [ -d "$skill" ] || return 0

  local ver
  ver=$(tr -d '[:space:]' < "$skill/scripts/VERSION" 2>/dev/null)
  [ -n "$ver" ] || { echo "impeccable-engine: no scripts/VERSION; skipping" >&2; return 0; }

  local os arch
  case "$(uname -s)" in
    Linux)  os=linux ;;
    Darwin) os=darwin ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) os=windows ;;
    *) echo "impeccable-engine: unsupported OS $(uname -s); skipping" >&2; return 0 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  arch=x64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) echo "impeccable-engine: unsupported arch $(uname -m); skipping" >&2; return 0 ;;
  esac

  local dest="$skill/scripts/bin/$os-$arch" bin
  bin="$dest/impeccable"; [ "$os" = windows ] && bin="$bin.exe"

  if [ -x "$bin" ] && [ "$(IMPECCABLE_LAUNCHER_PROBE=1 "$bin" engine-probe 2>/dev/null)" = "impeccable-engine $ver" ]; then
    echo "impeccable-engine $ver already present"
    return 0
  fi

  command -v npm >/dev/null 2>&1 || { echo "impeccable-engine: npm not found; skipping" >&2; return 0; }

  local pkg integrity tarball
  pkg="@impeccable/cli-$os-$arch"
  integrity=$(npm view "$pkg@$ver" dist.integrity 2>/dev/null | tr -d "'\" ")
  tarball=$(npm view "$pkg@$ver" dist.tarball 2>/dev/null | tr -d "'\" ")
  if [ -z "$integrity" ] || [ -z "$tarball" ]; then
    echo "impeccable-engine: no npm metadata for $pkg@$ver; skipping" >&2; return 0
  fi

  local tmp; tmp=$(mktemp -d) || return 0
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  curl -fsSL --retry 2 -o "$tmp/pkg.tgz" "$tarball" 2>/dev/null || {
    echo "impeccable-engine: download failed for $pkg@$ver; skipping" >&2; return 0; }

  local alg want got
  alg=${integrity%%-*}; want=${integrity#*-}
  case "$alg" in
    sha512) got=$(openssl dgst -sha512 -binary "$tmp/pkg.tgz" | openssl base64 -A) ;;
    sha256) got=$(openssl dgst -sha256 -binary "$tmp/pkg.tgz" | openssl base64 -A) ;;
    *) echo "impeccable-engine: unknown integrity algorithm '$alg'; refusing" >&2; return 0 ;;
  esac
  [ "$got" = "$want" ] || { echo "impeccable-engine: integrity mismatch for $pkg@$ver; refusing" >&2; return 0; }

  tar -xzf "$tmp/pkg.tgz" -C "$tmp" package/bin/ 2>/dev/null || {
    echo "impeccable-engine: no bin/ in $pkg@$ver; skipping" >&2; return 0; }
  local src; src=$(find "$tmp/package/bin" -type f | head -1)
  [ -n "$src" ] || { echo "impeccable-engine: empty bin/; skipping" >&2; return 0; }

  mkdir -p "$dest" && cp "$src" "$bin" && chmod +x "$bin" || {
    echo "impeccable-engine: install failed; skipping" >&2; return 0; }
  echo "impeccable-engine $ver installed from $pkg ($alg verified)"
}

# --------------------------------------------------------------------------
# 2. user-level skills
#
# Cross-project skills belong in ~/.claude/skills rather than vendored here,
# but that directory does not survive a cloud container, so re-clone whatever
# is missing. Format: "<dir-name> <clone-url>", one per line.
# --------------------------------------------------------------------------
USER_SKILLS="
napkin https://github.com/blader/napkin.git
"

install_user_skills() {
  local skills_dir="${HOME:-/nonexistent}/.claude/skills" name url dest
  while read -r name url; do
    [ -n "$name" ] && [ -n "$url" ] || continue
    dest="$skills_dir/$name"
    if [ -f "$dest/SKILL.md" ]; then
      echo "user skill '$name' already present"
      continue
    fi
    mkdir -p "$skills_dir" 2>/dev/null || {
      echo "user skill '$name': cannot write $skills_dir; skipping" >&2; continue; }
    rm -rf "$dest"
    if git clone --depth 1 --quiet "$url" "$dest" 2>/dev/null && [ -f "$dest/SKILL.md" ]; then
      echo "user skill '$name' cloned from $url"
    else
      rm -rf "$dest"
      echo "user skill '$name': clone failed from $url; skipping" >&2
    fi
  done <<< "$USER_SKILLS"
}

install_engine
install_user_skills
exit 0
