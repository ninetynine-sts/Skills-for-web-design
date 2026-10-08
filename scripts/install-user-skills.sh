#!/bin/bash
# Install this repo's skills for EVERY session on this machine, by linking them
# into the user skills dir (~/.claude/skills) instead of relying on a project
# checkout. Also installs the impeccable engine and any external user-level
# skills.
#
# Usage:
#   scripts/install-user-skills.sh            # engine + externals + link skills
#   scripts/install-user-skills.sh --no-link  # engine + externals only
#
# Intended for an environment Setup script (so it applies to every cloud
# session, in any repo) and safe to run by hand. Idempotent. Always exits 0: a
# skill that cannot be installed should degrade behavior, never block a session.
set -uo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
skills_dir="${HOME:-/nonexistent}/.claude/skills"
link_skills=1
[ "${1:-}" = "--no-link" ] && link_skills=0

# External skills that live at user level rather than in this repo.
# Format: "<dir-name> <clone-url>", one per line.
EXTERNAL_SKILLS="
napkin https://github.com/blader/napkin.git
"

# --------------------------------------------------------------------------
# impeccable engine: fetched from npm and verified against the sha512 npm
# publishes in dist.integrity, because the launcher's own fallback pulls from
# github.com release assets, which some sandboxes block. Fails closed.
# --------------------------------------------------------------------------
install_engine() {
  local skill="$repo/.agents/skills/impeccable" ver os arch dest bin
  [ -d "$skill" ] || return 0
  ver=$(tr -d '[:space:]' < "$skill/scripts/VERSION" 2>/dev/null)
  [ -n "$ver" ] || { echo "engine: no scripts/VERSION; skipping" >&2; return 0; }

  case "$(uname -s)" in
    Linux) os=linux ;; Darwin) os=darwin ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) os=windows ;;
    *) echo "engine: unsupported OS $(uname -s); skipping" >&2; return 0 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch=x64 ;; arm64|aarch64) arch=arm64 ;;
    *) echo "engine: unsupported arch $(uname -m); skipping" >&2; return 0 ;;
  esac

  dest="$skill/scripts/bin/$os-$arch"
  bin="$dest/impeccable"; [ "$os" = windows ] && bin="$bin.exe"
  if [ -x "$bin" ] && [ "$(IMPECCABLE_LAUNCHER_PROBE=1 "$bin" engine-probe 2>/dev/null)" = "impeccable-engine $ver" ]; then
    echo "engine $ver already present"; return 0
  fi
  command -v npm >/dev/null 2>&1 || { echo "engine: npm not found; skipping" >&2; return 0; }

  local pkg integrity tarball tmp alg want got src
  pkg="@impeccable/cli-$os-$arch"
  integrity=$(npm view "$pkg@$ver" dist.integrity 2>/dev/null | tr -d "'\" ")
  tarball=$(npm view "$pkg@$ver" dist.tarball 2>/dev/null | tr -d "'\" ")
  [ -n "$integrity" ] && [ -n "$tarball" ] || { echo "engine: no npm metadata for $pkg@$ver; skipping" >&2; return 0; }

  tmp=$(mktemp -d) || return 0
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  curl -fsSL --retry 2 -o "$tmp/pkg.tgz" "$tarball" 2>/dev/null || {
    echo "engine: download failed; skipping" >&2; return 0; }

  alg=${integrity%%-*}; want=${integrity#*-}
  case "$alg" in
    sha512) got=$(openssl dgst -sha512 -binary "$tmp/pkg.tgz" | openssl base64 -A) ;;
    sha256) got=$(openssl dgst -sha256 -binary "$tmp/pkg.tgz" | openssl base64 -A) ;;
    *) echo "engine: unknown integrity algorithm '$alg'; refusing" >&2; return 0 ;;
  esac
  [ "$got" = "$want" ] || { echo "engine: integrity mismatch; refusing" >&2; return 0; }

  tar -xzf "$tmp/pkg.tgz" -C "$tmp" package/bin/ 2>/dev/null || {
    echo "engine: no bin/ in package; skipping" >&2; return 0; }
  src=$(find "$tmp/package/bin" -type f | head -1)
  [ -n "$src" ] || { echo "engine: empty bin/; skipping" >&2; return 0; }
  mkdir -p "$dest" && cp "$src" "$bin" && chmod +x "$bin" || {
    echo "engine: install failed; skipping" >&2; return 0; }
  echo "engine $ver installed from $pkg ($alg verified)"
}

install_external_skills() {
  local name url dest
  while read -r name url; do
    [ -n "$name" ] && [ -n "$url" ] || continue
    dest="$skills_dir/$name"
    if [ -f "$dest/SKILL.md" ]; then echo "external skill '$name' already present"; continue; fi
    mkdir -p "$skills_dir" 2>/dev/null || { echo "external skill '$name': cannot write $skills_dir" >&2; continue; }
    rm -rf "$dest"
    if git clone --depth 1 --quiet "$url" "$dest" 2>/dev/null && [ -f "$dest/SKILL.md" ]; then
      echo "external skill '$name' cloned"
    else
      rm -rf "$dest"; echo "external skill '$name': clone failed from $url" >&2
    fi
  done <<< "$EXTERNAL_SKILLS"
}

# Symlink every skill in this repo into the user skills dir. Symlinks (not
# copies) so a `git pull` of this repo updates them with no reinstall.
link_repo_skills() {
  local src="$repo/.agents/skills" name target n=0
  [ -d "$src" ] || { echo "no .agents/skills in $repo" >&2; return 0; }
  mkdir -p "$skills_dir" 2>/dev/null || { echo "cannot write $skills_dir" >&2; return 0; }
  for target in "$src"/*/; do
    [ -f "$target/SKILL.md" ] || continue
    name=$(basename "$target")
    # Never clobber a real directory someone installed by hand; only replace
    # our own symlink or nothing at all.
    if [ -e "$skills_dir/$name" ] && [ ! -L "$skills_dir/$name" ]; then
      echo "skill '$name': a real directory already exists at user level; leaving it alone" >&2
      continue
    fi
    ln -sfn "${target%/}" "$skills_dir/$name" && n=$((n+1))
  done
  echo "linked $n skills from $repo into $skills_dir"
}

install_engine
install_external_skills
[ "$link_skills" = 1 ] && link_repo_skills
exit 0
