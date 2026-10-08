# Skills for web design

Agent skills for frontend/UI design work.

Skills live in `.agents/skills/` (the universal location, read by Codex, Amp,
Cline, Antigravity and ~20 other harnesses). `.claude/skills/` holds symlinks
into it so Claude Code picks up the same files.

## Installed

| Source | Skills |
|---|---|
| [`emilkowalski/skill`](https://github.com/emilkowalski/skill) | `animate`, `animate-expo`, `animation-vocabulary`, `apple-design`, `ask-sonner`, `break-ui`, `emil-design-eng`, `find-animation-opportunities`, `improve-animations`, `mobile-native`, `pick-ui-library`, `prototype`, `review-animations`, `write-swift` |
| [`pbakaus/impeccable`](https://github.com/pbakaus/impeccable) | `impeccable` |

`emilkowalski/skill` was installed with `npx skills add emilkowalski/skill` and
is tracked in `skills-lock.json`.

## The `impeccable` skill

`impeccable` is **not** in `skills-lock.json` — it was installed from a git
checkout rather than by its own installer, so there is no lockfile entry to
record. See below.

### Why it was installed by hand

`npx impeccable install` downloads a signed skill bundle from
`github.com/pbakaus/impeccable/releases`. Release-asset downloads are blocked
in some sandboxes (the cloud session this was installed from returns HTTP 403
for `github.com/.../releases` and `codeload.github.com`), and the installer
fails closed rather than installing something it cannot verify:

```
Download failed: Could not verify skill bundle: Expected a signed bundle
release redirect (HTTP 403). Nothing was installed.
```

Anonymous `git clone` of the same public repo is *not* blocked, so the skill
tree was copied from the repo at tag `engine-v0.1.5` instead. Same upstream
source, different transport — but note this path does **not** carry the
vendor's bundle-signature check. On a machine with normal network access,
prefer the real thing:

```sh
npx impeccable install
```

### The engine binary

The skill shells out to a compiled Rust engine via
`.agents/skills/impeccable/scripts/impeccable`. That binary is **deliberately
not committed** — it is ~16 MB and platform-specific, and the launcher fetches
the right one on first use.

The launcher resolves, in order: `$IMPECCABLE_BIN`, a binary sibling to the
script, `~/.impeccable/bin/impeccable`, the version-pinned cache
`~/.impeccable/bin/$(cat .agents/skills/impeccable/scripts/VERSION)/impeccable`,
then `impeccable` on `PATH`. It downloads from GitHub releases only as a last
resort and verifies against a `.sha256` sidecar.

Where releases are blocked, the npm registry still serves the same engine as a
platform package, which is how this checkout was set up:

```sh
npx -y impeccable --version   # populates the npx cache
mkdir -p ~/.impeccable/bin/0.1.5
cp "$(find /root/.npm/_npx -path '*@impeccable/cli-linux-x64/bin/impeccable' | head -1)" \
   ~/.impeccable/bin/0.1.5/impeccable
chmod +x ~/.impeccable/bin/0.1.5/impeccable
```

Version pairing matters: npm `impeccable@4.1.0` pins engine `0.1.5`, which is
why the skill was taken from tag `engine-v0.1.5` (skill `4.3.0`) rather than
`main` (skill `4.5.0`, engine `0.1.11`) — no `0.1.11` binary is reachable
without release downloads. Verify a pairing with:

```sh
.agents/skills/impeccable/scripts/impeccable engine-probe   # prints the engine version
.agents/skills/impeccable/scripts/impeccable doctor         # reports artifact drift
```

Without any engine the skill still loads and degrades gracefully — its `SKILL.md`
has an explicit "launcher unavailable" path — but you lose context loading,
screenshots, the live browser and the edit hooks.
