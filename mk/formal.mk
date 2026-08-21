# =====================================================================
# Shared SymbiYosys rules.
#
# An exercise Makefile sets:
#
#   ROOT     path back to the repo root
#   PROPS    the property file you are writing (or the design, in the
#            exercises where the properties are given and the design is
#            not)
#   REF      the reference version of the same file, in solutions/
#   SBYFILE  the sby config          (default: prove.sby)
#   TASKS    task:expected pairs     e.g. good:pass bad1:fail cover:pass
#
# Then:
#
#   make                 prove the harness still works, then run every
#                        task against YOUR file and check each verdict
#                        against the one it should be
#   make solution        the same against the reference
#   make <task>          run one task on its own and show sby's output
#   make trace TASK=t    print the counterexample from task t as a
#                        cycle-by-cycle table
#   make wave  TASK=t    open the same trace in gtkwave
#   make clean
#
# ---------------------------------------------------------------------
# WHY THE REFERENCE IS SWAPPED IN BY COPYING, NOT BY A [files] SWITCH
#
# sby resolves everything in [files] relative to the .sby file, and the
# task-conditional syntax works on script lines rather than file lines.
# Threading a "use the solution instead" switch through both would mean
# every exercise's prove.sby carrying two nearly identical copies of its
# file list, which is a thing to keep in step by hand and therefore a
# thing that will drift.
#
# Copying the reference over a scratch directory instead keeps prove.sby
# describing exactly one arrangement, and it is the same arrangement the
# student runs. `make solution' and `make' then differ in precisely one
# file, which is the property being taught.
# ---------------------------------------------------------------------

SBY      ?= sby
PYTHON   ?= python3
GTKWAVE  ?= gtkwave

SBYFILE  ?= prove.sby
TASK     ?=

EXNAME   := $(notdir $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST))))))
WORKDIR  := $(basename $(SBYFILE))

# TASKS is `name:expected' pairs; the bare names are also make targets, so
# that `make bad2' runs just that one. Generated rather than a `%:' catch
# all, which in make matches literally anything -- including `Makefile',
# which it would then try to rebuild.
TASKNAMES := $(foreach t,$(TASKS),$(firstword $(subst :, ,$(t))))

.PHONY: all solution selftest trace wave clean $(TASKNAMES)

# Bare `make' means `make all', and saying so is not optional.
#
# make takes its default goal from the FIRST target in the file, and this
# file is included by an exercise Makefile that defines no targets of its
# own -- so whatever happens to be first here is what a bare `make' runs.
# When `selftest' was added it landed above `all', and every exercise
# quietly started answering `make' with nothing but the self-test line.
#
# It survived a full-suite check because the repo-root sweep names the
# target: `$(MAKE) -C exercises/NN all'. Naming it meant the default-goal
# path was the one thing the sweep could not see.
.DEFAULT_GOAL := all

# Run against YOUR file, which is already where prove.sby expects it.
all: selftest
	@echo "  $(EXNAME) -- your properties"
	@$(ROOT)/mk/run.sh "$(SBY)" "$(CURDIR)/$(SBYFILE)" "$(EXNAME)" $(TASKS)

# The harness proves itself before it judges you. SELFTEST_DONE is set by
# the repo-root sweep, which has already run it once -- without that, a
# sweep over eleven exercises would re-prove the same ten fixtures eleven
# more times.
selftest:
	@if [ -z "$(SELFTEST_DONE)" ]; then $(ROOT)/mk/selftest.sh "$(SBY)"; fi

# Run against the reference. Build a scratch copy of the whole exercise
# with the reference file swapped in, so that sby sees one arrangement and
# your own work is never touched.
solution: selftest
	@echo "  $(EXNAME) -- reference properties"
	@rm -rf .ref && mkdir -p .ref
	@cp -r $(SBYFILE) $(wildcard *.v) $(wildcard dut) .ref/ 2>/dev/null || true
	@test -f "$(REF)" || { echo "  ERROR: no reference at $(REF)"; exit 1; }
	@cp "$(REF)" .ref/$(notdir $(PROPS))
	@$(ROOT)/mk/run.sh "$(SBY)" "$(CURDIR)/.ref/$(SBYFILE)" "$(EXNAME) (reference)" $(TASKS)

# One task, with sby's own output. This is what you run while actually
# working: `make bad2' and read what it says.
$(TASKNAMES):
	@$(SBY) -f $(SBYFILE) $@ 2>&1 | tail -n 30

# Print the counterexample as a table. The step sby names in its summary
# is passed through to the renderer so the column is marked.
trace:
	@test -n "$(TASK)" || { echo "  usage: make trace TASK=<task>"; exit 1; }
	@d=$(WORKDIR)_$(TASK); \
	 v=$$(ls $$d/engine_0/trace*.vcd 2>/dev/null | head -1); \
	 if [ -z "$$v" ]; then \
	   echo "  no trace for '$(TASK)'. Run  make $(TASK)  first --"; \
	   echo "  and note that a task that PASSES has no counterexample to show."; \
	   exit 1; \
	 fi; \
	 s=$$(grep -oE 'step [0-9]+' $$d/logfile.txt 2>/dev/null | tail -1 | tr -dc 0-9); \
	 echo "  $(TASK): $$v"; \
	 if [ -n "$$s" ]; then $(PYTHON) $(ROOT)/mk/trace.py $$v --mark $$s; \
	 else                  $(PYTHON) $(ROOT)/mk/trace.py $$v; fi

wave:
	@test -n "$(TASK)" || { echo "  usage: make wave TASK=<task>"; exit 1; }
	@d=$(WORKDIR)_$(TASK); \
	 v=$$(ls $$d/engine_0/trace*.vcd 2>/dev/null | head -1); \
	 test -n "$$v" || { echo "  no trace for '$(TASK)' -- run  make $(TASK)  first"; exit 1; }; \
	 $(GTKWAVE) $$v &

clean:
	@rm -rf $(WORKDIR)_* $(WORKDIR) .ref
