ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../..)

PROPS := props.v
REF   := $(ROOT)/solutions/08-liveness-and-fairness/props.v

TASKS := good:pass bad1:fail bad2:fail bad3:fail cover:pass

include $(ROOT)/mk/formal.mk
