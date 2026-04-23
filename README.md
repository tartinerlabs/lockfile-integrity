# Lockfile Integrity Check

**Your lockfile changed, but `package.json` didn't. Why?**

A zero dependency GitHub Action that catches suspicious lockfile modifications in pull requests, the kind that slip past code review and open the door to supply chain attacks.

Supports `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lock`, `bun.lockb`, and any custom lockfile via the `custom-lockfiles` input.

## The Problem

Lockfile only changes are one of the most overlooked vectors in npm supply chain attacks. An attacker (or a compromised CI step) can inject a malicious package resolution directly into the lockfile. Since lockfile diffs are large and noisy, reviewers rarely scrutinize them line by line.

This action makes that invisible change visible and blocks the PR until someone explains it.

## How It Works

```
PR opened
  |
  v
  git diff origin/main...HEAD
  |
  |__ lockfile changed?
  |     |
  |     |__ package.json / workspace / config also changed?  --> Pass (legitimate dependency update)
  |     |
  |     |__ none of those changed?                           --> Fail with annotation (possible tampering)
  |
  |__ no lockfile changed?              --> Skip (nothing to check)
```

## Quick Start

```yaml
name: Lockfile Integrity

on:
  pull_request:
    paths:
      - pnpm-lock.yaml
      - package-lock.json
      - yarn.lock
      - bun.lock

permissions:
  contents: read

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0  # Required: the action diffs against the base branch

      - uses: tartinerlabs/lockfile-integrity@v1
        with:
          base-ref: ${{ github.base_ref }}
```

That's it. The action auto detects which lockfile(s) changed. No configuration needed.

### Skip Checks for Bot-Generated PRs

Dependabot and Renovate often open lockfile-only maintenance PRs. Skip the check for trusted actors:

```yaml
- uses: tartinerlabs/lockfile-integrity@v1
  with:
    base-ref: ${{ github.base_ref }}
    allowed-actors: "dependabot[bot],renovate[bot]"
```

### Validate Registry URLs

For an additional layer of defence, restrict which registry hostnames are allowed in lockfile changes. Any URL pointing outside the allowlist will be flagged:

```yaml
- uses: tartinerlabs/lockfile-integrity@v1
  with:
    base-ref: ${{ github.base_ref }}
    allowed-registries: "registry.npmjs.org,registry.yarnpkg.com"
```

### Monitor Custom Lockfiles

The action knows npm, pnpm, yarn, and bun out of the box. For other ecosystems, add custom lockfiles:

```yaml
- uses: tartinerlabs/lockfile-integrity@v1
  with:
    base-ref: ${{ github.base_ref }}
    custom-lockfiles: "Gemfile.lock,Cargo.lock,flake.lock"
```

### Enable Verbose Logging

Useful for debugging why a check passed or failed:

```yaml
- uses: tartinerlabs/lockfile-integrity@v1
  with:
    base-ref: ${{ github.base_ref }}
    verbose: "true"
```

> **Tip:** For maximum supply chain safety, pin to a specific commit SHA instead of a mutable tag:
>
> ```yaml
> - uses: tartinerlabs/lockfile-integrity@<commit_sha>  # v1
> ```
>
> Tags can be moved to point at different commits. A SHA pin guarantees you run exactly the code you audited.

### Pin to a Specific Lockfile

If your repo uses a single package manager, you can be explicit:

```yaml
- uses: tartinerlabs/lockfile-integrity@v1
  with:
    base-ref: ${{ github.base_ref }}
    lockfile: pnpm-lock.yaml  # or package-lock.json, yarn.lock, bun.lock
```

### Warn Instead of Fail

Useful for rolling out gradually. Annotates the PR without blocking it:

```yaml
- uses: tartinerlabs/lockfile-integrity@v1
  with:
    base-ref: ${{ github.base_ref }}
    fail-on-warning: "false"
```

### Use Outputs in Downstream Steps

```yaml
- uses: tartinerlabs/lockfile-integrity@v1
  id: integrity
  with:
    base-ref: ${{ github.base_ref }}
    fail-on-warning: "false"

- if: steps.integrity.outputs.tampered == 'true'
  run: echo "Suspicious lockfiles: ${{ steps.integrity.outputs.lockfiles }}"
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `base-ref` | Yes | | Base branch for comparison (e.g. `main`) |
| `lockfile` | No | _(auto detect)_ | Lockfile to monitor; auto detects from changed files when omitted |
| `fail-on-warning` | No | `true` | Whether to fail the check or just warn |
| `allowed-actors` | No | `""` | Comma-separated GitHub actors to skip (e.g. `dependabot[bot]`) |
| `allowed-registries` | No | `""` | Comma-separated allowed registry hostnames (e.g. `registry.npmjs.org`) |
| `custom-lockfiles` | No | `""` | Comma-separated additional lockfile paths (e.g. `Gemfile.lock`) |
| `verbose` | No | `false` | Enable verbose logging for debugging |

## Outputs

| Output | Description |
|--------|-------------|
| `tampered` | `"true"` if lockfile tampering was detected, `"false"` otherwise |
| `lockfiles` | Space separated list of lockfiles that were modified |
| `suspicious-urls` | Space separated list of suspicious registry URLs detected |

## Requirements

The checkout step **must** use `fetch-depth: 0` so the action can diff against the base branch. Without it, the git history won't be available and the check will fail with a clear error message.

## FAQ

**Does this catch all supply chain attacks?**
No. This catches one specific signal: lockfile only changes. It's a lightweight tripwire, not a full dependency audit. Pair it with tools like `npm audit`, Socket, or Snyk for deeper analysis.

**What if I regenerate my lockfile intentionally?**
Touch `package.json` in the same PR (even a whitespace change counts) and the check passes. Changes to `pnpm-workspace.yaml`, `.npmrc`, `.yarnrc.yml`, `.yarnrc`, or `bunfig.toml` also count as legitimate triggers. Or use `fail-on-warning: "false"` to get a warning annotation instead of a hard failure. You can also add the PR author to `allowed-actors` if it's a trusted automation account.

**Does it work with monorepos?**
Yes. The action uses monorepo-aware matching: a lockfile in a subdirectory is validated against manifest files in that same directory (e.g. `apps/web/package-lock.json` is checked against `apps/web/package.json`), while root workspace configs still apply globally.

**Can I use this for non-JavaScript projects?**
Yes. Use the `custom-lockfiles` input to monitor lockfiles from any ecosystem (Ruby, Rust, Python, Nix, etc.).

## License

[MIT](LICENSE)
