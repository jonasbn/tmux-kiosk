# CI/Security Hardening TODO

Follow-up candidates identified after adding the ShellCheck and zizmor
workflows (PR #3). Tackle one at a time, each as its own PR.

- [ ] **Dependabot for GitHub Actions** — add `.github/dependabot.yml` with
  `package-ecosystem: "github-actions"` so the SHA-pinned actions in
  `shellcheck.yml` and `zizmor.yml` get automated update PRs instead of
  silently going stale.
- [x] **CI workflow for the bats test suite** — `tests/*.bats` exists but
  nothing runs it in CI. Add a workflow that installs bats and runs the
  suite on push/PR.
- [ ] **actionlint workflow** — complements zizmor (security) with
  correctness checks (bad `if:` expressions, invalid context refs, schema
  errors). Same SHA-pinning approach as the existing workflows.
- [ ] **markdownlint CI** — `.markdownlint.json` exists but isn't enforced
  anywhere; add a workflow that runs markdownlint in CI.
- [ ] **OSSF Scorecard workflow** — public supply-chain security score/badge;
  flags things like missing branch protection, unpinned deps, lack of SAST.
- [ ] **Branch protection ruleset on `main`** — repo setting, not a file;
  require ShellCheck/zizmor/tests checks (and a review) to pass before
  merge, so the new CI checks actually gate merges.
