#!/bin/bash
#
# Run the RetireSmartIRA test suite. Use this instead of calling xcodebuild directly.
#
# WHY THIS EXISTS
#
# Two mistakes were made repeatedly, and neither was fixed by writing a louder
# instruction. Both are now impossible here rather than merely discouraged.
#
#   1. OMITTING -project. This repo uses git worktrees, so several checkouts of
#      different branches sit side by side. `xcodebuild test` with no -project
#      picks one by scanning the working directory, and a shell whose cwd reset
#      between calls silently built a DIFFERENT worktree on a DIFFERENT branch.
#      It printed BUILD SUCCEEDED for code nobody had written. This script
#      derives the project from its OWN location, so it always tests the
#      checkout it lives in and cannot target another.
#
#   2. BACKGROUNDING THE RUN. The full suite takes five to six minutes. Agents
#      hit a 120 second default timeout, moved the run to the background, then
#      stalled waiting on it. Five separate agents lost a full turn each. This
#      script runs in the foreground and prints a short summary instead of tens
#      of thousands of lines, so there is no reason to background it. If your
#      tool has a timeout parameter, set it to 600000 milliseconds and call this.
#
# USAGE
#
#   tools/run-tests.sh                              # full suite
#   tools/run-tests.sh GoldenScenarioSingleYearTests
#   tools/run-tests.sh SuiteOne SuiteTwo            # several suites
#   tools/run-tests.sh --raw                        # unfiltered xcodebuild output
#
# EXIT CODES
#
#   0  everything passed, or the ONLY failing suite was the known
#      MultiYearPerfTests wall-clock flake AND it passed when re-run alone. The
#      script says so explicitly; it never hides a failure.
#   1  real failures, listed.
#   2  the build itself failed, so no tests ran.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/RetireSmartIRA.xcodeproj"
SCHEME="RetireSmartIRA"
DESTINATION="platform=macOS"

# The one suite known to fail for reasons unrelated to any change: a 15 second
# wall-clock budget missed by a fraction under full-suite CPU contention. It
# passes in isolation. This script VERIFIES that rather than assuming it.
KNOWN_FLAKE="MultiYearPerfTests"

if [ ! -d "$PROJECT" ]; then
    echo "FATAL: no project at $PROJECT" >&2
    echo "This script must live in <checkout>/tools/ so it can find its own project." >&2
    exit 2
fi

RAW=0
# Built as a single string rather than an array: macOS ships bash 3.2, where
# expanding an empty array under `set -u` is itself an error.
ONLY_TESTING=""
SCOPE_LABEL=""
for arg in "$@"; do
    case "$arg" in
        --raw) RAW=1 ;;
        -*)    echo "FATAL: unknown option $arg" >&2; exit 2 ;;
        *)     ONLY_TESTING="$ONLY_TESTING -only-testing:RetireSmartIRATests/$arg"
               SCOPE_LABEL="$SCOPE_LABEL $arg" ;;
    esac
done

LOG="$(mktemp -t rsi-tests)"

BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "Project:  $PROJECT"
echo "Branch:   $BRANCH @ $COMMIT"
if [ -n "$SCOPE_LABEL" ]; then
    echo "Scope:   $SCOPE_LABEL"
else
    echo "Scope:    full suite, five to six minutes. Run this in the FOREGROUND."
fi
echo

# shellcheck disable=SC2086
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    $ONLY_TESTING \
    > "$LOG" 2>&1

if [ "$RAW" -eq 1 ]; then
    cat "$LOG"
    rm -f "$LOG"
    exit 0
fi

# A build failure means no tests ran at all. That is a different problem from a
# test failure and gets its own exit code and output.
if ! grep -qE "Test run with|Executed [0-9]+ tests?" "$LOG"; then
    echo "BUILD FAILED. No tests ran. First errors:"
    grep -E "error:" "$LOG" | head -20
    echo
    echo "Full log kept at: $LOG"
    exit 2
fi

SWIFT_TESTING="$(grep -oE "Test run with [0-9]+ tests? in [0-9]+ suites? (passed|failed)" "$LOG" | tail -1)"
XCTEST="$(grep -oE "Executed [0-9]+ tests, with [0-9]+ failures \([0-9]+ unexpected\)" "$LOG" | tail -1)"
SKIPPED="$(grep -oE "[0-9]+ tests? skipped" "$LOG" | tail -1)"

# Which suites contain a failure. Swift Testing marks them with a heavy ballot X
# or "recorded an issue"; XCTest marks them with "error:" on a test line.
FAILURES="$(grep -E "recorded an issue|✘ Test|✘ Suite" "$LOG" \
            | grep -oE "[A-Za-z0-9_]+Tests" | sort -u)"
FAILURE_COUNT="$(printf '%s' "$FAILURES" | grep -c . || true)"

echo "================ RESULT ================"
[ -n "$SWIFT_TESTING" ] && echo "Swift Testing:  $SWIFT_TESTING"
[ -n "$XCTEST" ]        && echo "XCTest:         $XCTEST"
[ -n "$SKIPPED" ]       && echo "Skipped:        $SKIPPED (env-gated audit harness, expected)"
echo

# A run where nothing actually executed must never report PASS. The most likely
# cause is a mistyped suite name, and a wrapper that answers "PASS. No failures."
# to a typo is a false green, which is the exact class of failure this project
# has spent a program eliminating.
SWIFT_COUNT="$(printf '%s' "$SWIFT_TESTING" | grep -oE "with [0-9]+ tests?" | grep -oE "[0-9]+" || true)"
XCTEST_COUNT="$(printf '%s' "$XCTEST" | grep -oE "Executed [0-9]+" | grep -oE "[0-9]+" || true)"
[ -z "$SWIFT_COUNT" ] && SWIFT_COUNT=0
[ -z "$XCTEST_COUNT" ] && XCTEST_COUNT=0
TOTAL_RAN=$((SWIFT_COUNT + XCTEST_COUNT))

if [ "$TOTAL_RAN" -eq 0 ]; then
    echo "NOTHING RAN. Zero tests executed, so this is NOT a pass."
    if [ -n "$SCOPE_LABEL" ]; then
        echo "Most likely a mistyped suite name in:$SCOPE_LABEL"
        echo "Suite names are the Swift type names under RetireSmartIRATests/, for example"
        echo "GoldenScenarioSingleYearTests or StateTaxBehaviorBaselineTests."
    fi
    echo "Full log kept at: $LOG"
    exit 2
fi

if [ "$FAILURE_COUNT" -eq 0 ]; then
    echo "PASS. $TOTAL_RAN test(s) ran, no failures."
    rm -f "$LOG"
    exit 0
fi

echo "FAILING SUITES:"
printf '%s\n' "$FAILURES" | sed 's/^/  /'
echo

# If the only failing suite is the known flake, check that claim by re-running
# it alone. Do not wave it through on reputation.
if [ "$FAILURE_COUNT" -eq 1 ] && [ "$FAILURES" = "$KNOWN_FLAKE" ]; then
    echo "The only failing suite is $KNOWN_FLAKE, a known wall-clock flake."
    echo "Re-running it in isolation to check that claim..."
    echo
    ISO_LOG="$(mktemp -t rsi-flake)"
    xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
        "-only-testing:RetireSmartIRATests/$KNOWN_FLAKE" > "$ISO_LOG" 2>&1
    if grep -qE "^\*\* TEST SUCCEEDED \*\*" "$ISO_LOG"; then
        echo "  $KNOWN_FLAKE PASSED in isolation."
        echo "  Treating the full-suite failure as the known flake, NOT a regression."
        echo "  SAY THAT EXPLICITLY in any report, with this isolation result as the evidence."
        rm -f "$ISO_LOG" "$LOG"
        exit 0
    else
        echo "  $KNOWN_FLAKE FAILED IN ISOLATION TOO, so this is NOT the known flake."
        echo "  Treat it as a real failure. Isolated log: $ISO_LOG"
        exit 1
    fi
fi

echo "Failure detail:"
grep -E "recorded an issue|✘ Test|✘ Suite" "$LOG" | head -30
echo
echo "Full log kept at: $LOG"
exit 1
