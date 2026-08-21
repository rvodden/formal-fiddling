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
# and one verdict that is never expected, only reported:
#
#   empty     a `mode cover' task passed having reached no cover statement
#             at all, because there were none to reach. See below.
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
#
# ---------------------------------------------------------------------
# AND WHY AN EMPTY COVER RUN IS NOT A PASS
#
# The same failure wearing different clothes, found when a reader's
# exercise 01 went green with no cover statements in it at all.
#
# `mode cover' asks whether every cover statement can be reached. With no
# cover statements the answer is yes, trivially and instantly: sby returns
# PASS having checked nothing, and the line it prints is identical to the
# one a real cover run prints.
#
# That is precisely the hollow PASS exercise 04 is about, so a harness
# that awards it a tick is teaching the opposite of the lesson. A cover
# task that reached nothing therefore gets its own verdict, `empty', which
# -- like ERROR -- matches no expectation at all.
#
# The mode is read from the exercise's own prove.sby rather than sniffed
# out of sby's output. sby does reveal it, in the -c flag on the
# yosys-smtbmc command line, but that is one engine's spelling and the
# .sby file is where the exercise actually declares its intent.
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

# The sby mode for a task, from the [options] section: a `<task>: mode X'
# line if there is one, otherwise a bare `mode X' default.
mode_of() {
    awk -v task="$1" '
        /^\[/      { in_opts = ($0 ~ /^\[options\]/); next }
        !in_opts   { next }
                   { sub(/#.*/, "") }
        $1 == task ":" && $2 == "mode" { specific = $3 }
        $1 == "mode" { fallback = $2 }
        END        { print (specific != "" ? specific : fallback) }
    ' "$SBYFILE"
}

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

    # A cover run that reached nothing checked nothing. See the header.
    if [ "$got" = "pass" ] && [ "$(mode_of "$task")" = "cover" ]; then
        if ! printf '%s\n' "$out" | grep -q 'Reached cover statement'; then
            got=empty
        fi
    fi

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
            empty)
                report="$report
  $task passed without reaching a single cover statement, because the
      property file does not contain any. An empty cover set is
      satisfiable instantly and proves nothing -- which is exactly the
      hollow PASS exercise 04 is about, so it is not counted as one.
      Write the cover statements the exercise asks for.
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
