ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../..)

PROPS := props.v

# Exercise 00 is read, not written, so there is no separate reference:
# `make solution' and `make' run the same file. The variable is set anyway
# so that the repo-root sweep can treat every exercise identically.
#
# The comment is on its own line deliberately. A trailing `# ...' after a
# make assignment leaves the spaces before it INSIDE the variable, and a
# path with a trailing space fails `test -f' while looking perfectly
# correct in the error message.
REF := $(ROOT)/exercises/00-worked-example/props.v

TASKS := buggy:fail fixed:pass cover:pass vacuous:pass vacuous_cover:fail

include $(ROOT)/mk/formal.mk
