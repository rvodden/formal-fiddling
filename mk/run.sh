#!/bin/sh
# =====================================================================
# Run a set of SymbiYosys tasks and check each verdict against the one
# the exercise says it should produce.
#
#   run.sh <sby> <sby-file> <label> <task:expected> ...
#
# where <expected> is one of:
#
#   pass      the solver could not break it (bmc), or proved it (prove),
#             or reached the cover statements (cover)
#   fail      the solver produced a counterexample
#   unknown   `mode prove' only: the base case held but induction did
#             not close. The property may still be true -- see exercise 06.
#
# ---------------------------------------------------------------------
# WHY THIS SCRIPT EXISTS AT ALL, RATHER THAN JUST `sby -f prove.sby'
#
# Because in this repo a FAIL is frequently the correct answer. Most
# exercises ship one correct DUT and several broken ones, and a property
# set is only finished when it passes the first and fails all the rest.
# Reading that off a wall of sby output by eye is exactly the sort of
# thing you stop doing carefully around the fourth time.
#
# ---------------------------------------------------------------------
# WHY `ERROR' IS NOT ALLOWED TO COUNT AS `fail'
#
# This is the whole reason the verdict is parsed rather than taken from
# sby's exit status. sby exits non-zero for a failed proof AND for a
# design that did not compile, and those mean opposite things here.
#
# Put a typo in your property file, and every task that was supposed to
# FAIL still "fails" -- because nothing built. Six of the seven lines in
# the summary go green, the harness congratulates you, and you have
# verified nothing whatsoever. That is not a hypothetical: it is what the
# first version of this script did, and it stayed unnoticed for four
# exercises because the output looked like progress.
#
# So ERROR is its own verdict, it never matches anything, and it prints
# the compiler's complaint.
# =====================================================================

SBY="$1";      shift
SBYFILE="$1";  shift
LABEL="$1";    shift

if ! command -v "$SBY" >/dev/null 2>&1; then
    echo "  $LABEL: SKIPPED -- '$SBY' is not on PATH."
    echo "           Install SymbiYosys, or say  make SBY=yowasp-sby  (see README)."
    exit 0
fi

DIR=$(dirname "$SBYFILE")
FILE=$(basename "$SBYFILE")

fail=0
n=0
report=""

for spec in "$@"; do
    task=${spec%%:*}
    want=${spec#*:}
    n=$((n + 1))

    out=$(cd "$DIR" && "$SBY" -f "$FILE" "$task" 2>&1)

    # The last DONE line is the verdict. sby prints one per task and we
    # only ever ask it for one.
    verdict=$(printf '%s\n' "$out" | grep -oE 'DONE \((PASS|FAIL|UNKNOWN|ERROR|TIMEOUT)' | tail -1 | sed 's/DONE (//')

    case "$verdict" in
        PASS)    got=pass    ;;
        FAIL)    got=fail    ;;
        UNKNOWN) got=unknown ;;
        TIMEOUT) got=timeout ;;
        ERROR)   got=error   ;;
        *)       got=nothing ;;
    esac

    if [ "$got" = "$want" ]; then
        printf '  %-14s %-8s as expected\n' "$task" "$got"
    else
        fail=1
        printf '  %-14s %-8s WRONG -- expected %s\n' "$task" "$got" "$want"

        # Say why, because "bad3 passed and should not have" on its own
        # sends you reading the DUT when the answer is usually in your
        # own property file.
        case "$got" in
            error|nothing)
                report="$report
  $task did not build. sby said:
$(printf '%s\n' "$out" | grep -iE '^(ERROR|.*(ERROR:|syntax error))' | head -4 | sed 's/^/      /')
"
                ;;
            fail)
                report="$report
  $task produced a counterexample:
$(printf '%s\n' "$out" | grep -E 'summary: +(failed assertion|counterexample)' | head -3 | sed 's/.*summary: */      /')
      Read it with:  make trace TASK=$task
"
                ;;
            unknown)
                report="$report
  $task: the base case held, but induction did not close. That is not a
      counterexample -- the property may well be true. It means the
      solver cannot get there from an arbitrary state. See exercise 06.
"
                ;;
        esac
    fi
done

echo
if [ $fail -eq 0 ]; then
    echo "  PASS  ($n tasks, all verdicts as expected)"
    echo
    exit 0
fi

echo "  FAIL  -- $LABEL"
printf '%s\n' "$report"
exit 1
