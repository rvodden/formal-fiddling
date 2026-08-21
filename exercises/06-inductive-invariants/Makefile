ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../..)

PROPS := props.v
REF   := $(ROOT)/solutions/06-inductive-invariants/props.v

# prove_weak is expected to be UNKNOWN, not FAIL, and the difference is
# the point of the exercise. See mk/run.sh for the three-way verdict.
TASKS := bmc:pass prove_weak:unknown prove_strong:pass cover:pass

include $(ROOT)/mk/formal.mk
