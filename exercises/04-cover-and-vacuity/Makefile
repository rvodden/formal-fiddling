ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../..)

PROPS := props.v
REF   := $(ROOT)/solutions/04-cover-and-vacuity/props.v

TASKS := hollow:pass hollow_cover:fail honest:fail honest_cover:pass vacuity:pass

include $(ROOT)/mk/formal.mk
