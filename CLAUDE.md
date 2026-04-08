# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A GitHub composite action (`action.yml`) that detects lockfile changes (pnpm-lock.yaml, package-lock.json, yarn.lock, bun.lock) without corresponding manifest or config file modifications in a PR — a supply chain tamper signal.

## Outputs

- `tampered` — `"true"` if lockfile tampering was detected, `"false"` otherwise
- `lockfiles` — space-separated list of lockfiles that were modified

## Architecture

The entire action is a single file: `action.yml`. It uses `runs: using: composite` with an inline bash script. There is no build step, no compiled output, no dependencies, and no test framework.

The bash script:
1. Diffs changed files between the PR head and the base branch (`git diff --name-only`)
2. Resolves which lockfiles to check — uses the `lockfile` input if set, otherwise auto-detects from changed files against the known list (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lock`)
3. Exits early if no lockfile was modified
4. Passes if any `package.json`, `pnpm-workspace.yaml`, `.npmrc`, `.yarnrc.yml`, `.yarnrc`, or `bunfig.toml` was also changed
5. Fails (or warns) if only the lockfile changed
6. Writes `tampered` and `lockfiles` to `$GITHUB_OUTPUT`

## Inputs

- `base-ref` (required) — base branch for git diff comparison
- `lockfile` (default: `""`) — which lockfile to monitor; auto-detects from changed files when empty
- `fail-on-warning` (default: `"true"`) — exit 1 on detection, or just emit a GitHub warning

## Testing

No automated tests. To verify changes, create a test PR in a repo that uses this action with `fetch-depth: 0` on checkout.

## Key Constraints

- The action relies on `origin/$BASE_REF...HEAD` git diff, so consuming repos must use `fetch-depth: 0` in their checkout step.
- GitHub annotation syntax (`::error::`, `::warning::`) is used for PR feedback.
