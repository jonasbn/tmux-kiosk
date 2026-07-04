# CLAUDE.md

Guidance for Claude Code sessions working in this repository.

## Project

tmux-kiosk is a tmux plugin (pure bash, no external dependencies) that
auto-cycles windows on a timer. Entry point is `tmux-kiosk.tmux`, which binds
a key and a `session-closed` hook. Behavior lives in `scripts/`:

- `scripts/toggle.sh` — starts/stops the background switcher, tracks state via
  a PID file at `/tmp/tmux-kiosk-<session_id>.pid`.
- `scripts/switcher.sh` — the background loop that sleeps and calls
  `tmux next-window`.
- `scripts/cleanup.sh` — kills the switcher and removes the PID file when a
  session closes.

## Testing

Tests are bats (`tests/*.bats`). They never touch real tmux — a fake
`tmux` binary (`tests/helpers/fake_tmux`) is prepended to `PATH` in each
test's `setup()`, and logs calls to a temp file for assertions. Run locally:

```bash
bats tests/*.bats
```

**Known false failure in constrained sandboxes:** the test
`toggle: stops switcher and removes PID file when running` can fail in
environments where PID 1 isn't a real init (e.g. some containers use a
minimal supervisor instead of systemd). Killed background processes become
zombies that still answer `kill -0` until reaped, which the test reads as
"still running." This does not reproduce on GitHub Actions `ubuntu-latest`
runners (systemd reaps orphans) — confirmed green in CI. If this test fails
locally, check `ps -p 1 -o cmd` before assuming a real regression.

## CI

Three workflows in `.github/workflows/`, all following the same hardening
conventions (established via zizmor, see below):

- `shellcheck.yml` — lints every shell script (`scripts/*.sh`,
  `tmux-kiosk.tmux`, `tests/helpers/fake_tmux`) with ShellCheck, which is
  preinstalled on `ubuntu-latest` runners.
- `bats.yml` — installs bats via `apt-get install --no-install-recommends`
  and runs `tests/*.bats`.
- `zizmor.yml` — audits the workflows themselves with
  [zizmor](https://zizmor.sh) and uploads SARIF results to code scanning.
  Skips the SARIF upload on fork PRs (`GITHUB_TOKEN` is read-only there and
  the upload would otherwise fail).

`.github/dependabot.yml` keeps the pinned action SHAs below from going
stale (weekly PRs for the `github-actions` ecosystem).

### Workflow conventions (required for new/changed workflows)

- Third-party actions pinned to a full commit SHA with a `# vX.Y.Z` comment,
  e.g. `actions/checkout@<sha> # v7.0.0`. Get the SHA with
  `git ls-remote --tags https://github.com/<owner>/<repo>` — **watch for
  annotated tags**: if there's a `refs/tags/vX.Y.Z^{}` peeled ref, that
  commit SHA is the one to pin, not the tag object SHA above it (mixing
  these up trips zizmor's impostor-commit check, which only runs online/in
  CI, not with `--no-online-audits`).
- `permissions: {}` at the workflow level, narrowed to least-privilege per
  job. Any non-obvious permission (e.g. `security-events: write`) needs an
  inline explanatory comment or zizmor's `undocumented-permissions` audit
  flags it under the `auditor` persona.
- `persist-credentials: false` on every `actions/checkout`.
- A `concurrency` group per workflow to cancel superseded runs.
- Prefer tools preinstalled on the runner (shellcheck) or installed via
  `apt-get --no-install-recommends` over adding another marketplace action,
  to keep the pinned-dependency surface small.

### Verifying a workflow change before pushing

```bash
# shellcheck (already preinstalled in most dev environments; apt-get install -y shellcheck if not)
shellcheck scripts/*.sh tmux-kiosk.tmux tests/helpers/fake_tmux

# zizmor — install once with `pip install zizmor` or `uv tool install zizmor`
zizmor --no-online-audits --persona=auditor .github/workflows/
```

Zero findings under `--persona=auditor` is the bar; it's stricter than
zizmor's default CI persona and catches things (missing concurrency,
undocumented permissions) before they show up as PR review comments from
Copilot or code-scanning bot comments.

## Working conventions from recent sessions

- Each hardening item ships as its own branch + PR (see `docs/TODO.md` for
  the running list, currently: actionlint, markdownlint CI, OSSF Scorecard,
  branch protection ruleset remaining).
- Once a branch's PR merges, start the next branch fresh off `origin/main`
  rather than stacking on the old (now-merged) branch.
- Copilot's automated review has caught real issues twice so far
  (mismatched hash-pin comment, `apt-get install` pulling in recommended
  packages, stale wording in `docs/TODO.md`) — treat its inline comments as
  worth checking even though the top-level summary comment is usually just
  a restatement of the diff.
