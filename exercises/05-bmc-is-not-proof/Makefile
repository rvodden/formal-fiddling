ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../..)

PROPS := props.v
REF   := $(ROOT)/solutions/05-bmc-is-not-proof/props.v

TASKS := good:pass shallow:pass shallow_cover:fail deep:fail deep_cover:pass vacuity:pass

include $(ROOT)/mk/formal.mk
