TESTS:=test19433 test20459 test22523
include ../common.mak

$(ROOT)/test19433.done: run_args = --DRT-dont-eat-me
$(ROOT)/test20459.done: run_args = foo bar -- --DRT-gcopts=profile:1

$(ROOT)/test22523.done: extra_dflags += -unittest
$(ROOT)/test22523.done: run_args = -- --DRT-testmode=run-main
