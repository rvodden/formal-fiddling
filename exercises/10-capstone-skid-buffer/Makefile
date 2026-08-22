ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../..)

PROPS := props.v
REF   := $(ROOT)/solutions/10-capstone-skid-buffer/props.v

TASKS := good:pass bad1:fail bad2:fail bad3:fail prove:pass cover:pass vacuity:pass

include $(ROOT)/mk/formal.mk
