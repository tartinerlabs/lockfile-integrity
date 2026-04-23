# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A GitHub composite action (`action.yml`) that detects lockfile changes (pnpm-lock.yaml, package-lock.json, yarn.lock, bun.lock, bun.lockb, and custom lockfiles) without corresponding manifest or config file modifications in a PR — a supply chain tamper signal.

## Outputs

- `tampered` — `"true"` if lockfile tampering was detected, `"false"` otherwise
- `lockfiles` — space-separated list of lockfiles that were modified
- `suspicious-urls` — space-separated list of suspicious registry URLs detected

## Architecture

The entire action is a single file: `action.yml`. It uses `runs: using: composite` with an inline bash script. There is no build step, no compiled output, no dependencies, and no test framework.

The bash script:
1. Validates `base-ref` is provided and `origin/$BASE_REF` is a valid git ref
2. Skips the check if `github.actor` is in the `allowed-actors` list
3. Diffs changed files between the PR head and the base branch (`git diff --name-only`)
4. Resolves which lockfiles to check — uses the `lockfile` input if set, otherwise auto-detects from changed files against the known list plus any `custom-lockfiles`
5. Exits early if no lockfile was modified
6. Uses monorepo-aware manifest matching:
   - Root lockfiles check against any manifest or workspace config
   - Subdirectory lockfiles check against manifests in the same directory plus root workspace configs
7. Fails (or warns) if only the lockfile changed
8. If `allowed-registries` is set, extracts hostnames from URLs in the lockfile diff and flags any that are not in the allowlist
9. Writes `tampered`, `lockfiles`, and `suspicious-urls` to `$GITHUB_OUTPUT`

## Inputs

- `base-ref` (required) — base branch for git diff comparison
- `lockfile` (default: `""`) — which lockfile to monitor; auto-detects from changed files when empty
- `fail-on-warning` (default: `"true"`) — exit 1 on detection, or just emit a GitHub warning
- `allowed-actors` (default: `""`) — comma-separated GitHub actors to skip the check for
- `allowed-registries` (default: `""`) — comma-separated allowed registry hostnames for URL validation
- `custom-lockfiles` (default: `""`) — comma-separated additional lockfile paths
- `verbose` (default: `"false"`) — enable verbose logging

## Commits

Use release-please conventional commit format. `feat:` for new behaviour, `fix:` for bug fixes, `docs:` for documentation only, `chore:` for maintenance. Release-please drives versioning from these prefixes.

## Testing

Run `./test.sh` to execute the local bash test harness covering filename matching, subdirectory detection, manifest matching, actor allowlists, registry validation, custom lockfiles, and verbose mode.

## Key Constraints

- The action relies on `origin/$BASE_REF...HEAD` git diff, so consuming repos must use `fetch-depth: 0` in their checkout step.
- GitHub annotation syntax (`::error::`, `::warning::`) is used for PR feedback.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
