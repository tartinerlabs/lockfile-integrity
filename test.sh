#!/usr/bin/env bash
set -euo pipefail

# Test harness for lockfile-integrity action logic
# Simulates various scenarios to verify correctness

PASS=0
FAIL=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local desc="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $desc"
    ((PASS++)) || true
  else
    echo "  ✗ $desc"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    ((FAIL++)) || true
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local desc="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  ✓ $desc"
    ((PASS++)) || true
  else
    echo "  ✗ $desc"
    echo "    expected to contain: '$needle'"
    echo "    actual: '$haystack'"
    ((FAIL++)) || true
  fi
}

# ---------- Test 1: Exact filename matching (not substring) ----------
echo "Test 1: Exact filename matching"
CHANGED_FILES=$'backup-package-lock.json.old\npackage-lock.json\nfoo/yarn.lock'
LOCKFILES=()
for lf in package-lock.json yarn.lock; do
  if echo "$CHANGED_FILES" | grep -qE "(^|/)$lf$"; then
    LOCKFILES+=("$lf")
  fi
done
assert_eq "package-lock.json yarn.lock" "${LOCKFILES[*]}" "Matches exact filenames, not substrings"

# ---------- Test 2: Subdirectory lockfile matching ----------
echo "Test 2: Subdirectory lockfile matching"
CHANGED_FILES=$'apps/web/package-lock.json\npackage.json'
LOCKFILES=()
for lf in package-lock.json; do
  if echo "$CHANGED_FILES" | grep -qE "(^|/)$lf$"; then
    LOCKFILES+=("$lf")
  fi
done
assert_eq "package-lock.json" "${LOCKFILES[*]}" "Matches lockfile in subdirectory"

# ---------- Test 3: Manifest detection in subdirectory ----------
echo "Test 3: Manifest detection in subdirectory"
CHANGED_FILES=$'apps/web/package-lock.json\napps/web/package.json'
lf_dir="apps/web"
manifest_pattern="(^|/)${lf_dir}/(package\\.json|\\.npmrc)$|(^|/)(pnpm-workspace\\.yaml|\\.yarnrc\\.yml|\\.yarnrc|bunfig\\.toml)$"
HAS_MANIFEST=false
if echo "$CHANGED_FILES" | grep -qE "$manifest_pattern"; then
  HAS_MANIFEST=true
fi
assert_eq "true" "$HAS_MANIFEST" "Detects package.json in same subdirectory"

# ---------- Test 4: Root manifest detection ----------
echo "Test 4: Root manifest detection"
CHANGED_FILES=$'package-lock.json\npackage.json'
manifest_pattern='(^|/)(package\.json|pnpm-workspace\.yaml|\.npmrc|\.yarnrc\.yml|\.yarnrc|bunfig\.toml)$'
HAS_MANIFEST=false
if echo "$CHANGED_FILES" | grep -qE "$manifest_pattern"; then
  HAS_MANIFEST=true
fi
assert_eq "true" "$HAS_MANIFEST" "Detects root package.json"

# ---------- Test 5: Subdirectory lockfile without local manifest ----------
echo "Test 5: Subdirectory lockfile without local manifest"
CHANGED_FILES=$'apps/web/package-lock.json\nother/package.json'
lf_dir="apps/web"
manifest_pattern="(^|/)${lf_dir}/(package\\.json|\\.npmrc)$|(^|/)(pnpm-workspace\\.yaml|\\.yarnrc\\.yml|\\.yarnrc|bunfig\\.toml)$"
HAS_MANIFEST=false
if echo "$CHANGED_FILES" | grep -qE "$manifest_pattern"; then
  HAS_MANIFEST=true
fi
assert_eq "false" "$HAS_MANIFEST" "Does not match unrelated subdirectory manifest"

# ---------- Test 6: Subdirectory lockfile with workspace config ----------
echo "Test 6: Subdirectory lockfile with workspace config"
CHANGED_FILES=$'apps/web/package-lock.json\npnpm-workspace.yaml'
lf_dir="apps/web"
manifest_pattern="(^|/)${lf_dir}/(package\\.json|\\.npmrc)$|(^|/)(pnpm-workspace\\.yaml|\\.yarnrc\\.yml|\\.yarnrc|bunfig\\.toml)$"
HAS_MANIFEST=false
if echo "$CHANGED_FILES" | grep -qE "$manifest_pattern"; then
  HAS_MANIFEST=true
fi
assert_eq "true" "$HAS_MANIFEST" "Matches workspace config for subdirectory lockfile"

# ---------- Test 7: Actor allowlist ----------
echo "Test 7: Actor allowlist"
ALLOWED_ACTORS="dependabot[bot],renovate[bot]"
GITHUB_ACTOR="dependabot[bot]"
SKIPPED=false
IFS=',' read -ra ACTORS <<< "$ALLOWED_ACTORS"
for actor in "${ACTORS[@]}"; do
  actor=$(echo "$actor" | xargs)
  if [ "$GITHUB_ACTOR" = "$actor" ]; then
    SKIPPED=true
    break
  fi
done
assert_eq "true" "$SKIPPED" "Skips check for allowed actor"

# ---------- Test 8: Actor not in allowlist ----------
echo "Test 8: Actor not in allowlist"
ALLOWED_ACTORS="dependabot[bot]"
GITHUB_ACTOR="malicious-user"
SKIPPED=false
IFS=',' read -ra ACTORS <<< "$ALLOWED_ACTORS"
for actor in "${ACTORS[@]}"; do
  actor=$(echo "$actor" | xargs)
  if [ "$GITHUB_ACTOR" = "$actor" ]; then
    SKIPPED=true
    break
  fi
done
assert_eq "false" "$SKIPPED" "Does not skip for disallowed actor"

# ---------- Test 9: Registry URL extraction ----------
echo "Test 9: Registry URL extraction"
LOCKFILE_DIFF=$'+      "resolved": "https://registry.npmjs.org/foo/-/foo-1.0.0.tgz",\n+      resolved "https://evil.com/bar/-/bar-1.0.0.tgz"'
URL_HOSTS=$(echo "$LOCKFILE_DIFF" | grep -oE 'https?://[^/"]+' | sed -e 's|^http://||' -e 's|^https://||' | sort -u)
assert_contains "$URL_HOSTS" "evil.com" "Extracts evil.com"
assert_contains "$URL_HOSTS" "registry.npmjs.org" "Extracts registry.npmjs.org"

# ---------- Test 10: Registry allowlist validation ----------
echo "Test 10: Registry allowlist validation"
ALLOWED_REGISTRIES="registry.npmjs.org,registry.yarnpkg.com"
URL_HOSTS=$'evil.com\nregistry.npmjs.org'
SUSPICIOUS=()
IFS=',' read -ra REGISTRIES <<< "$ALLOWED_REGISTRIES"
while IFS= read -r host; do
  [ -z "$host" ] && continue
  ALLOWED=false
  for reg in "${REGISTRIES[@]}"; do
    reg=$(echo "$reg" | xargs)
    if [ "$host" = "$reg" ]; then
      ALLOWED=true
      break
    fi
  done
  if [ "$ALLOWED" = "false" ]; then
    SUSPICIOUS+=("$host")
  fi
done <<< "$URL_HOSTS"
assert_eq "evil.com" "${SUSPICIOUS[*]}" "Flags disallowed registry hostname"

# ---------- Test 11: Empty suspicious URLs ----------
echo "Test 11: Empty suspicious URLs"
SUSPICIOUS_URLS=()
if [ ${#SUSPICIOUS_URLS[@]} -gt 0 ]; then
  UNIQUE_URLS=$(printf '%s\n' "${SUSPICIOUS_URLS[@]}" | sort -u | tr '\n' ' ' | sed 's/ $//')
else
  UNIQUE_URLS=""
fi
assert_eq "" "$UNIQUE_URLS" "Handles empty suspicious URLs correctly"

# ---------- Test 12: Binary file detection ----------
echo "Test 12: Binary file detection"
LOCKFILE_DIFF=$'Binary files a/bun.lockb and b/bun.lockb differ'
IS_BINARY=false
if echo "$LOCKFILE_DIFF" | grep -q "^Binary files"; then
  IS_BINARY=true
fi
assert_eq "true" "$IS_BINARY" "Detects binary lockfile diff"

# ---------- Test 13: Custom lockfiles ----------
echo "Test 13: Custom lockfiles"
KNOWN_LOCKFILES=(pnpm-lock.yaml package-lock.json yarn.lock bun.lock bun.lockb)
CUSTOM_LOCKFILES="Gemfile.lock,Cargo.lock"
if [ -n "$CUSTOM_LOCKFILES" ]; then
  IFS=',' read -ra EXTRA_LOCKFILES <<< "$CUSTOM_LOCKFILES"
  for clf in "${EXTRA_LOCKFILES[@]}"; do
    clf=$(echo "$clf" | xargs)
    [ -z "$clf" ] && continue
    KNOWN_LOCKFILES+=("$clf")
  done
fi
assert_contains "${KNOWN_LOCKFILES[*]}" "Gemfile.lock" "Adds Gemfile.lock"
assert_contains "${KNOWN_LOCKFILES[*]}" "Cargo.lock" "Adds Cargo.lock"

# ---------- Test 14: Verbose logging ----------
echo "Test 14: Verbose logging"
VERBOSE="true"
LOG_OUTPUT=""
log() {
  if [ "$VERBOSE" = "true" ]; then
    LOG_OUTPUT="$LOG_OUTPUT[lockfile-integrity] $1"
  fi
}
log "test message"
assert_contains "$LOG_OUTPUT" "[lockfile-integrity] test message" "Verbose log is emitted"

# ---------- Test 15: Non-verbose logging ----------
echo "Test 15: Non-verbose logging"
VERBOSE="false"
LOG_OUTPUT=""
log() {
  if [ "$VERBOSE" = "true" ]; then
    LOG_OUTPUT="$LOG_OUTPUT[lockfile-integrity] $1"
  fi
}
log "test message"
assert_eq "" "$LOG_OUTPUT" "No log emitted when verbose is false"

# ---------- Test 16: Empty base-ref validation ----------
echo "Test 16: Empty base-ref validation"
BASE_REF=""
VALIDATION_FAILED=false
if [ -z "$BASE_REF" ]; then
  VALIDATION_FAILED=true
fi
assert_eq "true" "$VALIDATION_FAILED" "Detects empty base-ref"

# ---------- Test 17: Custom lockfile auto-detect ----------
echo "Test 17: Custom lockfile auto-detect"
CHANGED_FILES=$'backend/Cargo.lock\nbackend/Cargo.toml'
CUSTOM_LOCKFILES="Cargo.lock"
KNOWN_LOCKFILES=(pnpm-lock.yaml package-lock.json yarn.lock bun.lock bun.lockb)
if [ -n "$CUSTOM_LOCKFILES" ]; then
  IFS=',' read -ra EXTRA_LOCKFILES <<< "$CUSTOM_LOCKFILES"
  for clf in "${EXTRA_LOCKFILES[@]}"; do
    clf=$(echo "$clf" | xargs)
    [ -z "$clf" ] && continue
    KNOWN_LOCKFILES+=("$clf")
  done
fi
LOCKFILES=()
for lf in "${KNOWN_LOCKFILES[@]}"; do
  if echo "$CHANGED_FILES" | grep -qE "(^|/)$lf$"; then
    LOCKFILES+=("$lf")
  fi
done
assert_eq "Cargo.lock" "${LOCKFILES[*]}" "Auto-detects custom lockfile"

# ---------- Summary ----------
echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
