#!/bin/bash
# Session bootstrap for sessions started FROM this repo.
#
# This repo's skills already load as project skills, so only two things are
# needed: the compiled engine the `impeccable` skill shells out to, and any
# external user-level skills whose home (~/.claude/skills) is ephemeral in a
# cloud container. Both live in scripts/install-user-skills.sh so there is one
# copy of the logic; --no-link skips the user-level symlinks that would just
# duplicate the project skills here.
#
# For the skills to load in EVERY session regardless of repo, run that script
# without --no-link from the environment's Setup script instead. See README.
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
installer="$root/scripts/install-user-skills.sh"

if [ -x "$installer" ]; then
  "$installer" --no-link
else
  echo "session-start: $installer missing or not executable; skipping" >&2
fi
exit 0
