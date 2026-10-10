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
| [`Leonxlnx/taste-skill`](https://github.com/Leonxlnx/taste-skill) | `brandkit`, `design-taste-frontend`, `design-taste-frontend-v1`, `full-output-enforcement`, `gpt-taste`, `high-end-visual-design`, `image-to-code`, `imagegen-frontend-mobile`, `imagegen-frontend-web`, `industrial-brutalist-ui`, `minimalist-ui`, `redesign-existing-projects`, `stitch-design-taste` |
| [`LottieFiles/motion-design-skill`](https://github.com/LottieFiles/motion-design-skill) | `motion-design` |
| [`pbakaus/impeccable`](https://github.com/pbakaus/impeccable) | `impeccable` |

`emilkowalski/skill`, `Leonxlnx/taste-skill` and `LottieFiles/motion-design-skill`
were installed with `npx skills add <repo>` and are tracked in `skills-lock.json`
(28 skills, each with a content hash). All three are markdown-only — no scripts
or binaries.

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

## MCP servers

`scripts/install-user-skills.sh` also re-registers user-scope MCP servers, since
`claude mcp add -s user` writes to `~/.claude.json`, which is ephemeral in a
cloud container.

| Server | Package | Key |
|---|---|---|
| `designmd` | `designmd-mcp` | `DESIGNMD_API_KEY` |

Add one by appending a `"<name> <env-var> <command...>"` line to `MCP_SERVERS`
in that script.

### Keys stay out of the repo

The key is registered as `${DESIGNMD_API_KEY}`, not as a literal. Claude Code
expands it when it launches the server, so the secret lives in the environment
and never reaches `~/.claude.json`, this repo, or a chat message.

Set it in the environment settings (cloud environment menu in the session title
bar → Edit) under **Network secrets**, or as a plain environment variable where
that section is not offered. A new session picks it up. Locally, export it from
your shell profile.

Until it is set, the server registers and connects but cannot authenticate, and
Claude Code says so:

```
[Warning] [designmd] mcpServers.designmd: Missing environment variables: DESIGNMD_API_KEY
```

## Claude account skills (works in Claude *and* Code, everywhere)

Uploading a skill to your Claude account is the only route that reaches plain
Claude conversations as well as Claude Code, on every device, with no per-repo
or per-environment setup.

Build the upload bundles with:

```sh
./scripts/package-account-skills.sh
```

Then upload at **claude.ai → Settings → Capabilities → Skills**.

**One skill per zip.** The uploader enforces it:

> Zip must contain exactly one top-level folder.
> Zip must contain exactly one SKILL.md file.

So a combined archive of several skills is rejected — upload them individually.
The script verifies every zip against both rules before you spend an upload.

`impeccable` is excluded and cannot be an account skill: it shells out to a
compiled engine, so it needs a shell and a filesystem. It stays Claude Code only.

Skills that audit a codebase (`break-ui`, `improve-animations`,
`find-animation-opportunities`, `review-animations`, `redesign-existing-projects`)
upload fine but have nothing to read in a chat with no repo. The script prints the
subset worth having in plain chat.

## Using these skills in EVERY session (any repo)

Project skills only load for the repo they live in. To get all of them in every
session regardless of repo, install them at **user level** with:

```sh
scripts/install-user-skills.sh
```

It symlinks every skill in `.agents/skills/` into `~/.claude/skills/`, installs
the impeccable engine, and clones the external user-level skills. Symlinks, not
copies — so `git pull` in this repo updates them with no reinstall. Idempotent,
and it never clobbers a real directory you installed by hand.

On your own machine, run it once and you are done.

### Cloud sessions

`~/.claude/` is ephemeral in a cloud container, so it has to run per session.
Put this in the environment's **Setup script** (cloud environment menu in the
session title bar → Edit) and every cloud session, in any repo, gets all the
skills:

```sh
REPO=~/.claude/skills-src/Skills-for-web-design
[ -d "$REPO/.git" ] || git clone --depth 1 https://github.com/ninetynine-sts/Skills-for-web-design "$REPO"
git -C "$REPO" pull --ff-only -q 2>/dev/null || true
"$REPO/scripts/install-user-skills.sh"
```

That self-updates: each session pulls the latest skills before installing.

Sessions started from *this* repo do not need it — `.claude/hooks/session-start.sh`
runs the same script with `--no-link`, since the project skills already load and
user-level copies would only duplicate them.

## User-level skills

Some skills are cross-project and belong in `~/.claude/skills/` rather than
vendored here — they should apply in every repo, not just this one. In a cloud
container that directory is **ephemeral**, so a fresh session starts without
them.

`.claude/hooks/session-start.sh` re-clones whatever is missing. To add one, append
a `"<dir-name> <clone-url>"` line to the `USER_SKILLS` list in that script.

Currently restored:

| Skill | Source | Notes |
|---|---|---|
| `napkin` | [`blader/napkin`](https://github.com/blader/napkin) | Always-on. Maintains a curated `.claude/napkin.md` runbook per repo. |

This only covers sessions started **from this repo**. For a user-level skill to
appear in *every* cloud session regardless of repo, put the clone in the
environment's **Setup script** instead (cloud environment menu in the session
title bar → Edit):

```sh
mkdir -p ~/.claude/skills
[ -d ~/.claude/skills/napkin ] || git clone --depth 1 https://github.com/blader/napkin.git ~/.claude/skills/napkin
```

On your own machine neither is needed — `~/.claude/skills/` persists there, so a
plain `git clone` is permanent and `git -C ~/.claude/skills/napkin pull` updates it.
