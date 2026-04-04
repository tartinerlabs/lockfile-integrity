# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A GitHub composite action (`action.yml`) that detects lockfile changes (pnpm-lock.yaml, package-lock.json, yarn.lock, bun.lock) without corresponding `package.json` modifications in a PR — a supply chain tamper signal.

## Architecture

The entire action is a single file: `action.yml`. It uses `runs: using: composite` with an inline bash script. There is no build step, no compiled output, no dependencies, and no test framework.

The bash script:
1. Diffs changed files between the PR head and the base branch (`git diff --name-only`)
2. Exits early if the lockfile wasn't modified
3. Passes if any `package.json` was also changed
4. Fails (or warns) if only the lockfile changed

## Inputs

- `base-ref` (required) — base branch for git diff comparison
- `lockfile` (default: `pnpm-lock.yaml`) — which lockfile to monitor
- `fail-on-warning` (default: `"true"`) — exit 1 on detection, or just emit a GitHub warning

## Testing

No automated tests. To verify changes, create a test PR in a repo that uses this action with `fetch-depth: 0` on checkout.

## Key Constraints

- The action relies on `origin/$BASE_REF...HEAD` git diff, so consuming repos must use `fetch-depth: 0` in their checkout step.
- GitHub annotation syntax (`::error::`, `::warning::`) is used for PR feedback.
