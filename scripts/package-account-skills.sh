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
# Output (dist/, gitignored):
#   <skill>.zip                   one per skill, as <name>/SKILL.md
#   CURATED-for-claude-chat.zip   the ones worth having in a plain chat
#   ALL-design-skills.zip         every packaged skill in one archive
set -uo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
src="$repo/.agents/skills"
out="$repo/dist/account-skills"

# Needs a compiled engine and a shell, so it cannot work as an account skill.
EXCLUDE="impeccable"

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
  case " $EXCLUDE " in *" $n "*) skipped="$skipped $n(needs-runtime)"; continue ;; esac
  # A skill shipping non-markdown files usually implies a runtime the chat
  # surface does not have; leave those to Claude Code.
  if find "$n" -type f ! -name '*.md' | grep -q .; then
    skipped="$skipped $n(non-md)"; continue
  fi
  zip -q -r "$out/$n.zip" "$n" && made=$((made+1))
done

curated_found=""
for n in $CURATED; do
  [ -f "$n/SKILL.md" ] && curated_found="$curated_found $n" || echo "curated: '$n' not found, skipping" >&2
done
# shellcheck disable=SC2086
[ -n "$curated_found" ] && zip -q -r "$out/CURATED-for-claude-chat.zip" $curated_found

ex=(); for n in $EXCLUDE; do ex+=(-x "$n/*" -x "$n"); done
zip -q -r "$out/ALL-design-skills.zip" . "${ex[@]}"

echo "packaged $made skills into $out"
[ -n "$skipped" ] && echo "skipped:$skipped"
echo "curated bundle:$curated_found"
