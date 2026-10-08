# Skills for web design

Agent skills for frontend/UI design work.

Skills live in `.agents/skills/` (the universal location, read by Codex, Amp,
Cline, Antigravity and ~20 other harnesses). `.claude/skills/` holds symlinks
into it so Claude Code picks up the same files.

Clone the repo and the skills are active — nothing to install. A
`SessionStart` hook preinstalls the one compiled dependency `impeccable`
needs; see below.

## Installed

| Source | Skills |
|---|---|
| [`emilkowalski/skill`](https://github.com/emilkowalski/skill) | `animate`, `animate-expo`, `animation-vocabulary`, `apple-design`, `ask-sonner`, `break-ui`, `emil-design-eng`, `find-animation-opportunities`, `improve-animations`, `mobile-native`, `pick-ui-library`, `prototype`, `review-animations`, `write-swift` |
| [`pbakaus/impeccable`](https://github.com/pbakaus/impeccable) | `impeccable` |

`emilkowalski/skill` was installed with `npx skills add emilkowalski/skill` and
is tracked in `skills-lock.json`.

## The `impeccable` skill

Installed by hand rather than by `npx impeccable install`, so it has no
`skills-lock.json` entry. Pinned to upstream tag **`engine-v0.1.5`**
(skill `4.3.0`, engine `0.1.5`).

### Why not the official installer

`npx impeccable install` fetches a signed bundle from
`github.com/pbakaus/impeccable/releases`. Release-asset downloads are blocked
in some sandboxes — the cloud session this was installed from gets HTTP 403 for
both `github.com/.../releases` and `codeload.github.com` — and the installer
fails closed rather than install what it cannot verify:

```
Download failed: Could not verify skill bundle: Expected a signed bundle
release redirect (HTTP 403). Nothing was installed.
```

Anonymous `git clone` of the same public repo is *not* blocked, so the skill
tree was copied from the repo at that tag instead.

**This path carries no vendor bundle signature.** What stands in for it:

- **Skill files** — all 56 are byte-identical to upstream tag `engine-v0.1.5`
  (commit `112703d5bf2469574758e0ddc5baf8e03c958f58`), confirmed by comparing
  each file's git blob hash against `git ls-tree` at that tag.
- **Engine binary** — the npm tarball
  `@impeccable/cli-linux-x64@0.1.5` matches the `dist.integrity` sha512 npm
  publishes, and the binary extracted from it is sha256
  `cf5231a4b1ae66996c85b033800b1dad0797e590eae2f21ef2579430af187f19`.

Re-verify any time:

```sh
.agents/skills/impeccable/scripts/impeccable engine-probe   # -> impeccable-engine 0.1.5
.agents/skills/impeccable/scripts/impeccable doctor         # artifact drift report
```

### The engine binary (fetched, never committed)

The skill shells out to a compiled Rust engine. No binary is committed — it is
16 MB and platform-specific. Instead `.claude/hooks/session-start.sh` runs on
every session start and preinstalls it:

1. Detects `<os>-<arch>` the same way the launcher does.
2. Exits early if a working engine of the right version is already there.
3. Otherwise fetches `@impeccable/cli-<os>-<arch>` at the version in
   `scripts/VERSION` from npm, **verifies the tarball against the sha512 in
   npm's published `dist.integrity`**, and installs it to
   `scripts/bin/<os>-<arch>/` — the "binary shipped next to this script" slot
   the launcher checks before any network fetch.

That path is gitignored. npm is reachable in sandboxes where GitHub release
assets are not, which is the point. The hook fails closed on a verification
mismatch and exits 0 on any other problem, so a missing engine degrades the
skill rather than breaking the session.

Run it by hand any time:

```sh
./.claude/hooks/session-start.sh
```

Launcher resolution order: `$IMPECCABLE_BIN`, the sibling binary the hook
installs, `~/.impeccable/bin/impeccable`, the version-pinned cache
`~/.impeccable/bin/$(cat .agents/skills/impeccable/scripts/VERSION)/impeccable`,
then `impeccable` on `PATH`, then download from GitHub releases as a last
resort.

With no engine at all the skill still loads and degrades gracefully — its
`SKILL.md` has an explicit "launcher unavailable" path — but you lose context
loading, screenshots, the live browser and the edit hooks.

### Upgrading

Version pairing matters. npm `impeccable@4.1.0` pins engine `0.1.5`, which is
why tag `engine-v0.1.5` was used rather than `main` (skill `4.5.0`, engine
`0.1.11`) — engine binaries live only in release assets, so no `0.1.11` binary
was reachable. Where `github.com` is allowed, prefer the real thing, which
restores signature checking and gets you current:

```sh
npx impeccable install
```
