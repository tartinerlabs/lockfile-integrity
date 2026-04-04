# Lockfile Integrity Check

A GitHub Action that detects lockfile changes without corresponding `package.json` modifications — a supply chain tamper signal.

## Why?

If `pnpm-lock.yaml` (or `package-lock.json`, `yarn.lock`) changes in a PR but no `package.json` was touched, it could indicate:

- Lockfile tampering (malicious dependency injection)
- Accidental lockfile regeneration
- An indirect dependency resolution change that should be reviewed

## Usage

```yaml
name: Lockfile Integrity

on:
  pull_request:
    paths:
      - pnpm-lock.yaml

permissions:
  contents: read

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - uses: tartinerlabs/lockfile-integrity@v1
        with:
          base-ref: ${{ github.base_ref }}
```

### npm

```yaml
on:
  pull_request:
    paths:
      - package-lock.json

# ...
      - uses: tartinerlabs/lockfile-integrity@v1
        with:
          base-ref: ${{ github.base_ref }}
          lockfile: package-lock.json
```

### yarn

```yaml
on:
  pull_request:
    paths:
      - yarn.lock

# ...
      - uses: tartinerlabs/lockfile-integrity@v1
        with:
          base-ref: ${{ github.base_ref }}
          lockfile: yarn.lock
```

### Warn-only mode

To emit a warning instead of failing the check:

```yaml
      - uses: tartinerlabs/lockfile-integrity@v1
        with:
          base-ref: ${{ github.base_ref }}
          fail-on-warning: "false"
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `base-ref` | Yes | — | Base branch for comparison (e.g. `main`) |
| `lockfile` | No | `pnpm-lock.yaml` | Path to the lockfile to monitor |
| `fail-on-warning` | No | `true` | Whether to fail the check or just warn |

## Requirements

The checkout step must use `fetch-depth: 0` so the action can diff against the base branch.

## License

MIT
