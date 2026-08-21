# Top-level convenience targets.
#
#   make            the harness self-test, then every exercise against
#                   YOUR property files
#   make solutions  the same against the reference property files. This
#                   should always pass -- if it does not, the harness is
#                   broken rather than you
#   make selftest   just the harness self-test
#   make clean
#
# Needs SymbiYosys, yosys and an SMT solver. If you installed them with
# pip, the binaries have different names, so say:
#
#   make SBY=yowasp-sby
#
# and see the README for the two shims that yowasp needs on PATH.

SBY ?= sby

EXERCISES := 00-worked-example 01-first-assertions 02-reasoning-about-time \
             03-assuming-the-environment 04-cover-and-vacuity \
             05-bmc-is-not-proof 06-inductive-invariants \
             07-abstraction-anyconst 08-liveness-and-fairness \
             09-equivalence 10-capstone-skid-buffer

.PHONY: all test solutions selftest clean

all: test

# Deliberately not `all: selftest test'. The self-test has to run FIRST
# and has to stop everything if it fails, because every line the exercises
# print afterwards is the harness's word for it -- and a broken harness
# does not go quiet, it goes green.
#
# Note the sweep below runs a BARE `make' in each exercise rather than
# naming `all'. That is deliberate too. Naming the target skips make's
# default-goal resolution, which is the one thing an exercise Makefile
# leaves entirely to mk/formal.mk -- and a sweep that names it cannot see
# a default goal that has drifted onto some other target. It happened:
# adding `selftest' put it first in the file, so every exercise answered
# a bare `make' with the self-test line and nothing else, while this sweep
# stayed green throughout. Run what a reader runs.
test: selftest
	@fail=0; \
	for e in $(EXERCISES); do \
	  printf '%-28s ' $$e; \
	  if $(MAKE) -s -C exercises/$$e SBY=$(SBY) SELFTEST_DONE=1 >/dev/null 2>&1; \
	    then echo PASS; else echo FAIL; fail=1; fi; \
	done; \
	echo; \
	if [ $$fail -eq 0 ]; then echo "  all $(words $(EXERCISES)) exercises give the expected verdicts"; \
	else echo "  not there yet -- run make in the exercise directory to see why"; fi; \
	exit $$fail

solutions: selftest
	@fail=0; \
	for e in $(EXERCISES); do \
	  printf '%-28s ' $$e; \
	  if $(MAKE) -s -C exercises/$$e solution SBY=$(SBY) SELFTEST_DONE=1 >/dev/null 2>&1; \
	    then echo PASS; else echo FAIL; fail=1; fi; \
	done; \
	echo; \
	if [ $$fail -eq 0 ]; then echo "  every reference property set gives the expected verdicts"; \
	else echo "  A REFERENCE FAILED. That is the harness, not you."; fi; \
	exit $$fail

selftest:
	@mk/selftest.sh "$(SBY)"

clean:
	@for e in $(EXERCISES); do $(MAKE) -s -C exercises/$$e clean; done
	@rm -rf mk/selftest/probe mk/selftest/probe_*
