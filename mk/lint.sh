#!/bin/sh
#
# mk/lint.sh <yosys> <top-module> <file>...
#
# Ported from the Wishbone repository's lint, and pointed at property
# files rather than at designs. The bugs are the same shape; what changes
# is how they hurt.
#
# In a design, a width mismatch means the hardware misbehaves. In a
# PROPERTY file it means the check you thought you wrote is not the check
# you wrote -- and a property that has quietly become weaker does not
# fail. It passes, and so does every broken design you pointed it at.
#
# This is not a substitute for running the tasks. The tasks ask whether
# your properties get the right verdicts; this asks whether the Verilog
# you wrote says what you meant.
#
# It catches:
#
#   * an assignment whose two sides are different widths. THE one this
#     exists for. Verilog resizes silently, and in a property file the
#     usual casualty is a "did exactly one bit change" test:
#
#         wire       changed = gray ^ old_gray;   // 1 bit, not 4
#         assert((changed & (changed - 1)) == 0);
#
#     `changed' holds bit 0 and nothing else. The assertion is then true
#     of every value it can ever hold, so it can never fail -- against any
#     design, ever. Nothing in a task result distinguishes that from a
#     property that is genuinely satisfied.
#
#   * a typo'd signal name. `default_nettype none' is supposed to make
#     this a compile error and, in yosys, DOES NOT -- it warns and carries
#     on, inventing the wire:
#
#         old_grey <= grey;   // both names invented, real old_gray never set
#
#     So the warning is promoted to a failure here.
#
#   * a signal assigned with both `=' and `<=' in one always block.
#
#   * a register driven from more than one always block, and inferred
#     latches -- the same yosys checks the Wishbone lint runs, which apply
#     to a property file's own bookkeeping registers exactly as they do to
#     a design's.
#
# Not ported: the flip-flop ceiling and the area report, because property
# files are never synthesised and neither means anything here.
#
# Also not ported: the Wishbone lint's unused-net check, and the reason is
# worth writing down. It fires on a signal that is declared and never
# used -- which in a finished design is the fossil of an idea you changed
# your mind about, and in an EXERCISE is the normal state of the file you
# have not finished yet. Exercise 03 hands you a `latency' wire to write
# assertions against; until you have written them, it is unused, and the
# lint would report that as a fault on a fresh clone.
#
# A check that fires when nothing is wrong gets ignored, and it takes the
# checks that matter with it. mk/lint-unused.py is kept in the tree for
# anyone who wants to point it at a finished property file by hand.

set -e

YOSYS="$1"; shift
TOP="$1";   shift

VERILATOR="${VERILATOR:-verilator}"

if [ -z "$TOP" ]; then
    echo "  lint: no LINT_TOP set for this directory -- nothing to do"
    exit 0
fi

if ! command -v "$YOSYS" >/dev/null 2>&1; then
    echo "  lint: '$YOSYS' not found -- skipping."
    echo "        Install yosys, or run:  make lint YOSYS=yowasp-yosys"
    exit 0
fi

WIDTH=$(mktemp 2>/dev/null  || echo "./.lint-width.log");  WIDTH_BAD=0
ASSIGN=$(mktemp 2>/dev/null || echo "./.lint-assign.log"); ASSIGN_BAD=0
SCOPE=$(mktemp 2>/dev/null  || echo "./.lint-scope.log");  SCOPE_BAD=0
LOG=$(mktemp 2>/dev/null    || echo "./.lint.log")
: > "$WIDTH"

cleanup() { rm -f "$WIDTH" "$ASSIGN" "$SCOPE" "$LOG"; }

if command -v python3 >/dev/null 2>&1; then
    python3 "$(dirname "$0")/lint-assign.py" $* > "$ASSIGN" 2>&1 || ASSIGN_BAD=1
    python3 "$(dirname "$0")/lint-scope.py"  $* > "$SCOPE"  2>&1 || SCOPE_BAD=1
fi

# ---------------------------------------------------------------------
# Width, via verilator. Not something yosys will tell you and not
# something a task result can: the resize is legal, silent, and identical
# in simulation and synthesis, so the only way to find it is to have the
# widths computed and compared.
#
# Skipped rather than failed when verilator is absent, and the skip is
# printed -- a check you cannot see not running is worse than no check.
#
# -Wno-lint turns off the style warnings and leaves the two width ones,
# which is the whole reason for running it. Property files use $past,
# assert, assume and (* anyconst *); verilator parses all of them without
# complaint, which was checked rather than assumed.
# ---------------------------------------------------------------------
if command -v "$VERILATOR" >/dev/null 2>&1; then
    if ! "$VERILATOR" --lint-only -Wno-lint \
              -Wwarn-WIDTHTRUNC -Wwarn-WIDTHEXPAND \
              --top-module "$TOP" $* >> "$WIDTH" 2>&1
    then
        WIDTH_BAD=1
    fi
else
    echo "  lint: width check skipped ($TOP) -- verilator not on PATH."
    echo "        That is the check this lint mainly exists for; install it."
fi

# ---------------------------------------------------------------------
# yosys. ORDER MATTERS: `check -assert' runs BEFORE `opt', because opt
# resolves a flop-versus-constant conflict by keeping the constant, and
# after that a design whose reset was thrown away reports clean.
#
# read_verilog needs -formal here, unlike in the Wishbone repo: these
# files contain assert, assume, cover and $past, and plain read_verilog
# rejects all four.
# ---------------------------------------------------------------------
YOSYS_BAD=0
"$YOSYS" -p "
        read_verilog -formal $*
        hierarchy -top $TOP -check
        proc
        check -assert
        select -assert-none t:\$dlatch t:\$adlatch t:\$dlatchsr
        opt
        check -assert
    " > "$LOG" 2>&1 || YOSYS_BAD=1

grep -qi 'conflict' "$LOG" && YOSYS_BAD=1

# `default_nettype none' is supposed to make a typo'd name a compile
# error. yosys only warns, so the warning is promoted here -- otherwise
# the safety net docs/style.md relies on has a hole in exactly the place
# a beginner falls through it.
IMPLICIT_BAD=0
grep -q 'implicitly declared' "$LOG" && IMPLICIT_BAD=1

if [ "$YOSYS_BAD" = "0" ] && [ "$IMPLICIT_BAD" = "0" ] && [ "$WIDTH_BAD" = "0" ] \
&& [ "$ASSIGN_BAD" = "0" ] && [ "$SCOPE_BAD" = "0" ]; then
    echo "  lint: $TOP clean"
    cleanup
    exit 0
fi

echo "  lint: $TOP FAILED"
echo

if [ "$IMPLICIT_BAD" = "1" ]; then
    grep 'implicitly declared' "$LOG" | sed 's/^/    /' | sort -u
    echo
    cat <<'EOT'
    ------------------------------------------------------------------
    TYPO'D SIGNAL NAME

    A name that was never declared. `default_nettype none' at the top of
    the file is supposed to make this a compile error; yosys warns and
    invents the wire anyway, so this lint promotes it.

    It matters more here than in a design. An invented wire is one bit
    wide and driven by nothing, so:

        old_grey <= grey;      // neither name exists; both are invented

    leaves the REAL old_gray never assigned -- stuck at whatever reset
    gave it -- while the line you wrote appears to do the update. Every
    property that reads it then quietly tests the wrong thing.
    ------------------------------------------------------------------
EOT
fi

# verilator stops at hard errors before it gets as far as width
# inference, so a typo'd name makes it fail WITHOUT any width warning. Tell
# the two apart, or a missing variable gets an essay about resizing.
WIDTH_REAL=0
grep -q 'WIDTHTRUNC\|WIDTHEXPAND' "$WIDTH" && WIDTH_REAL=1

if [ "$WIDTH_BAD" = "1" ] && [ "$WIDTH_REAL" = "0" ] && [ "$IMPLICIT_BAD" = "0" ]; then
    # verilator objected to something that is neither a width nor a name
    # this lint already reported. Show it raw rather than guess.
    sed -n 's/^%\(Warning\|Error\)[^:]*: *\(.*\)$/    \2/p; s/^ *\([0-9]\+\) |\(.*\)$/        \1 |\2/p' "$WIDTH" \
        | sed -e '/^ *Exiting due to/d' -e 's/[[:space:]]*$//'
    echo
fi

if [ "$WIDTH_REAL" = "1" ]; then
    sed -n 's/^%\(Warning\|Error\)[^:]*: *\(.*\)$/    \2/p; s/^ *\([0-9]\+\) |\(.*\)$/        \1 |\2/p' "$WIDTH" \
        | sed -e '/^ *Exiting due to/d' -e 's/[[:space:]]*$//' \
        | grep -v "Can't find definition of variable"
    echo
    cat <<'EOT'
    ------------------------------------------------------------------
    WIDTH MISMATCH

    The two sides of an assignment are different widths, so Verilog
    resized one of them for you. Legal, silent, and identical in
    simulation and synthesis -- which is why nothing but this check can
    find it.

    In a property file the damage is specific and nasty: a property that
    has been narrowed does not fail, it WEAKENS. The classic is a
    one-bit-changed test:

        wire       changed = gray ^ old_gray;      // 1 bit, wanted 4
        assert((changed & (changed - 1)) == 0);

    With one bit, `changed' is 0 or 1 and the assertion is true of both.
    It can never fail, against any design. Every task still runs, and the
    broken designs it was meant to catch sail through.

    Write the width you meant:

        wire [3:0] changed = gray ^ old_gray;

    If you want to know whether an assertion has gone vacuous this way,
    ask the solver: cover its negation. If that cover statement is
    unreachable, the assertion cannot fail and is checking nothing.
    ------------------------------------------------------------------
EOT
fi

if [ "$ASSIGN_BAD" = "1" ]; then
    cat "$ASSIGN"
    echo
    cat <<'EOT'
    ------------------------------------------------------------------
    BLOCKING AND NON-BLOCKING ON THE SAME SIGNAL

    `<=' evaluates every right-hand side before updating any left-hand
    side, which is what a flip-flop does. `=' updates immediately. Using
    both on one signal makes the outcome depend on the order the
    simulator happens to evaluate your statements.

    In a clocked block, use `<=' for everything that becomes a register.
    ------------------------------------------------------------------
EOT
fi

if [ "$SCOPE_BAD" = "1" ]; then
    cat "$SCOPE"
    echo
    cat <<'EOT'
    ------------------------------------------------------------------
    LOOP VARIABLE SCOPED TOO WIDELY

    An `integer' at module level that only one block uses. The moment a
    second block borrows it, the two are writing one register. Move it
    inside the block -- which must be NAMED to hold a declaration:

        always @(posedge clk) begin : shift_block
            integer i;
    ------------------------------------------------------------------
EOT
fi

if [ "$YOSYS_BAD" = "1" ]; then
    awk '{
            line = $0
            gsub(/\[[0-9]+\]/, "[*]", line)
            if (!(line in cnt)) order[++n] = line
            cnt[line]++
         }
         END {
            for (i = 1; i <= n && i <= 30; i++)
                if (cnt[order[i]] > 1) printf "    %s   (x%d)\n", order[i], cnt[order[i]]
                else                   printf "    %s\n", order[i]
            if (n > 30) printf "    ... and %d more lines\n", n - 30
         }' "$LOG"
    echo
    if grep -qi 'conflict' "$LOG"; then
        cat <<'EOT'
    ------------------------------------------------------------------
    MULTIPLE DRIVERS

    A register is assigned from more than one always block. Synthesis
    must build one flip flop with one input, so it picks a driver and
    discards the rest -- usually the reset, because that tends to be the
    block sitting on its own.

    ONE REGISTER, ONE always BLOCK, with its reset inside it.
    ------------------------------------------------------------------
EOT
    fi
    if grep -q 'dlatch' "$LOG"; then
        cat <<'EOT'
    ------------------------------------------------------------------
    INFERRED LATCH

    An `always @*' block does not assign its output on every path, so a
    level-sensitive latch was built to remember the old value. Assign a
    default at the top of the block.
    ------------------------------------------------------------------
EOT
    fi
fi

cleanup
exit 1
