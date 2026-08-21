#!/bin/sh
# =====================================================================
# Prove that mk/run.sh still tells the four verdicts apart.
#
#   selftest.sh <sby>
#
# ---------------------------------------------------------------------
# WHY
#
# Every result in this repository is mk/run.sh comparing a verdict it
# parsed against a verdict an exercise expected. If that parsing breaks,
# it does not go quiet -- it reports something, and what it reports looks
# exactly like a result.
#
# The specific failure to be afraid of is the one that reads ERROR as
# FAIL. Most tasks here are SUPPOSED to fail, so a property file that does
# not compile would light up green across four exercises out of five and
# congratulate you on catching bugs you had not caught. That is not
# hypothetical -- it happened while exercise 00 was being written, and it
# is why the verdict is parsed out of sby's summary rather than taken from
# its exit status, which cannot tell the two apart.
#
# The same applies to an empty cover run, which sby reports exactly as it
# reports a real one -- see the note in run.sh.
#
# So: a fixture per verdict, each checked in both directions -- the
# harness must accept the right expectation and reject every wrong one.
# =====================================================================

SBY="${1:-sby}"
HERE=$(dirname "$0")
RUN="$HERE/run.sh"
SBYFILE="$HERE/selftest/probe.sby"

if ! command -v "$SBY" >/dev/null 2>&1; then
    echo "  harness self-test: SKIPPED -- '$SBY' is not on PATH"
    exit 0
fi

ok=0
n=0
out=""

# check <task> <expectation> <accept|reject>
#
# `accept' means run.sh must be happy with that expectation; `reject'
# means it must not be.
check() {
    task=$1; want=$2; should=$3
    n=$((n + 1))
    if "$RUN" "$SBY" "$SBYFILE" selftest "$task:$want" >/dev/null 2>&1; then
        got=accept
    else
        got=reject
    fi
    if [ "$got" = "$should" ]; then
        ok=$((ok + 1))
    else
        out="$out  $task expected as '$want': the harness ${got}ed it, and should have ${should}ed it\n"
    fi
}

# Each verdict is recognised...
check verdict_pass    pass    accept
check verdict_fail    fail    accept
check verdict_unknown unknown accept

# ...and is not confused with its neighbours.
check verdict_pass    fail    reject
check verdict_fail    pass    reject
check verdict_unknown pass    reject
check verdict_unknown fail    reject

# A cover run that reached something is a pass...
check verdict_cover   pass    accept

# ...and one that reached nothing, because the property file has no cover
# statements, is not. sby reports the two identically; the harness must
# not. Accepting it would award a tick for the exact hollow PASS that
# exercise 04 exists to teach against.
check verdict_empty   pass    reject
check verdict_empty   fail    reject
check verdict_empty   unknown reject

# THE IMPORTANT ONES. A design that does not build must not satisfy any
# expectation at all -- least of all `fail', which is what most tasks in
# this repo are expecting and which would therefore hide a broken property
# file behind a wall of green.
check verdict_error   fail    reject
check verdict_error   pass    reject
check verdict_error   unknown reject

if [ $ok -eq $n ]; then
    echo "  harness self-test: $ok/$n ok"
    exit 0
fi

echo "  harness self-test: $ok/$n ok -- THE HARNESS IS NOT WORKING"
echo
printf "$out"
echo
echo "  Until this is fixed, ignore every other result in this repository."
echo "  A harness that has stopped working does not report that it has"
echo "  stopped working. It reports verdicts, which is also what it does"
echo "  when it is fine, and you cannot tell them apart by looking."
exit 1
