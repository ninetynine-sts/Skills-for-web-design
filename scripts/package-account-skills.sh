#!/bin/bash
# Package these skills as zips for upload to claude.ai account skills
# (Settings -> Capabilities -> Skills), which makes them available in BOTH
# Claude and Claude Code, on every device, with no per-repo or per-environment
# setup.
#
# Account skills are server-side: a manifest of skillId/name/description, synced
# down to ~/.claude/skills/synced/. Nothing on disk can register one, so this
# only builds the artifacts you upload by hand.
#
# The uploader accepts ONE SKILL PER ZIP and rejects anything else:
#   "Zip must contain exactly one top-level folder."
#   "Zip must contain exactly one SKILL.md file."
# So this builds one zip per skill and no combined archive -- a bundle of
# several skills is rejected on upload. Upload them one at a time.
#
# Output (dist/, gitignored):
#   <skill>.zip   one per skill, as <name>/SKILL.md
set -uo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
src="$repo/.agents/skills"
out="$repo/dist/account-skills"

# Cannot work as account skills regardless of file types, because they drive an
# external CLI or compiled engine that a plain chat has no way to run.
#   impeccable   -- compiled Rust engine
#   hyperframes* -- the HyperFrames CLI (`hyperframes <verb>`, `heygen ...`)
EXCLUDE="impeccable hyperframes hyperframes-cli hyperframes-core
hyperframes-registry hyperframes-studio hyperframes-animation hyperframes-audio
hyperframes-creative hyperframes-keyframes slideshow media-use motion-graphics
general-video faceless-explainer product-launch-video pr-to-video music-to-video
remotion-to-hyperframes talking-head-recut embedded-captions figma"

# Work in a plain conversation: design taste, style systems, image direction,
# and reference knowledge. The rest need a repo to read or a shell to run.
CURATED="design-taste-frontend high-end-visual-design minimalist-ui
industrial-brutalist-ui brandkit imagegen-frontend-web imagegen-frontend-mobile
apple-design emil-design-eng animation-vocabulary mobile-native pick-ui-library"

command -v zip >/dev/null 2>&1 || { echo "zip not found" >&2; exit 1; }
[ -d "$src" ] || { echo "no $src" >&2; exit 1; }

rm -rf "$out"; mkdir -p "$out"
cd "$src" || exit 1

made=0 skipped=""
for d in */; do
  n=${d%/}
  [ -f "$n/SKILL.md" ] || continue
  # Collapse newlines: EXCLUDE spans several lines, and a space-delimited
  # match silently misses any entry sitting at the start of a line.
  case " $(printf '%s' "$EXCLUDE" | tr '\n' ' ') " in
    *" $n "*) skipped="$skipped $n(needs-runtime)"; continue ;;
  esac
  # A skill shipping non-markdown files usually implies a runtime the chat
  # surface does not have; leave those to Claude Code.
  #
  # No pipe here, deliberately. `find ... | grep -q .` is wrong under
  # `set -o pipefail`: grep -q exits at the first match, find dies of SIGPIPE,
  # and pipefail reports the pipeline as failed -- so the guard reads "no
  # non-md files" and packages the skill anyway. It is a race, so it caught
  # small skills and missed large ones.
  if [ -n "$(find "$n" -type f ! -name '*.md' -print -quit)" ]; then
    skipped="$skipped $n(non-md)"; continue
  fi
  zip -q -r "$out/$n.zip" "$n" && made=$((made+1))
done



# Verify each zip against the uploader's rules before anyone wastes an upload.
fail=0
for z in "$out"/*.zip; do
  tops=$(unzip -Z1 "$z" | awk -F/ '{print $1}' | sort -u | wc -l)
  one=$(unzip -Z1 "$z" | grep -c '^[^/]*/SKILL\.md$')
  if [ "$tops" -ne 1 ] || [ "$one" -ne 1 ]; then
    echo "INVALID $(basename "$z"): top-level folders=$tops SKILL.md=$one" >&2; fail=1
  fi
done
[ "$fail" = 0 ] && echo "all zips valid: exactly one top-level folder and one SKILL.md each"

echo "packaged $made skills into $out"
[ -n "$skipped" ] && echo "skipped:$skipped"
echo
echo "Upload one at a time at claude.ai -> Settings -> Capabilities -> Skills."
echo "Worth having in a plain chat (no repo, no shell):"
for n in $CURATED; do [ -f "$out/$n.zip" ] && echo "  $n.zip"; done
