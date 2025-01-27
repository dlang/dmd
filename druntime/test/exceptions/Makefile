ifeq ($(OS),linux)
    # FIXME: detect musl libc robustly; just checking Alpine Linux' apk tool for now
    ifeq (1,$(shell which apk &>/dev/null && echo 1))
        IS_MUSL:=1
    endif
endif

TESTS=stderr_msg unittest_assert invalid_memory_operation static_dtor \
      future_message refcounted rt_trap_exceptions_drt catch_in_finally \
      message_with_null

# FIXME: segfaults with musl libc
ifneq ($(IS_MUSL),1)
TESTS += unknown_gc
endif

# fails on 32 bit linux
ifneq ($(OS),linux)
TESTS += assert_fail
endif

DIFF:=diff
SED:=sed
GDB:=gdb

ifeq ($(OS),linux)
    TESTS+=line_trace line_trace_21656 long_backtrace_trunc rt_trap_exceptions cpp_demangle
    # registerMemoryAssertHandler requires glibc
    ifneq ($(IS_MUSL),1)
        TESTS+=memoryerror_null_read memoryerror_null_write memoryerror_null_call memoryerror_stackoverflow
    endif
    line_trace_dflags:=-L--export-dynamic
endif

ifeq ($(OS),linux)
# Only add this test if gdb is available.
    ifneq (,$(shell which $(GDB) > /dev/null 2>&1 && echo 1))
	TESTS+=rt_trap_exceptions_drt_gdb
    endif
endif

ifeq ($(OS),freebsd)
    TESTS+=line_trace line_trace_21656 long_backtrace_trunc cpp_demangle
    line_trace_dflags:=-L--export-dynamic
endif
ifeq ($(OS),dragonflybsd)
    TESTS+=line_trace line_trace_21656 long_backtrace_trunc cpp_demangle
    line_trace_dflags:=-L--export-dynamic
endif
ifeq ($(OS),osx)
    TESTS+=line_trace line_trace_21656 cpp_demangle
    line_trace_dflags:=
endif
ifeq ($(OS)-$(BUILD),windows-debug)
    TESTS+=winstack
endif
include ../common.mak

$(ROOT)/line_trace.done: $(ROOT)/line_trace$(DOTEXE)
	@echo Testing line_trace
	$(TIMELIMIT)$(ROOT)/line_trace > $@
	# Use sed to canonicalize line_trace.done and compare against expected output in line_trace.exp
	$(SED) "s|^.*/src/|src/|g; s/\[0x[0-9a-f]*\]/\[ADDR\]/g; s/scope //g; s/Nl//g" $@ | $(DIFF) line_trace.exp -

# https://issues.dlang.org/show_bug.cgi?id=21656
$(ROOT)/line_trace_21656.done: $(ROOT)/line_trace$(DOTEXE)
	@echo Testing line_trace_21656
	@mkdir -p $(ROOT)/line_trace_21656
	@touch $(ROOT)/line_trace_21656/line_trace
	cd $(ROOT)/line_trace_21656 && PATH="..:$$PATH" $(TIMELIMIT)line_trace > line_trace.output
	$(SED) "s|^.*/src/|src/|g; s/\[0x[0-9a-f]*\]/\[ADDR\]/g; s/scope //g; s/Nl//g" $(ROOT)/line_trace_21656/line_trace.output | $(DIFF) line_trace.exp -
	@rm -rf $(ROOT)/line_trace_21656
	@touch $@

$(ROOT)/long_backtrace_trunc.done: $(ROOT)/long_backtrace_trunc$(DOTEXE)
	@echo Testing long_backtrace_trunc
	$(TIMELIMIT)$(ROOT)/long_backtrace_trunc > $(ROOT)/long_backtrace_trunc.output
	# Use sed to canonicalize long_backtrace_trunc.output and compare against expected output in long_backtrace_trunc.exp
	$(SED) "s|^.*/src/|src/|g; s/\[0x[0-9a-f]*\]/\[ADDR\]/g; s/scope //g; s/Nl//g" $(ROOT)/long_backtrace_trunc.output | $(DIFF) long_backtrace_trunc.exp -
	@rm -f $(ROOT)/long_backtrace_trunc.output
	@touch $@

$(ROOT)/chain.done: $(ROOT)/chain$(DOTEXE)
	@echo Testing chain
	$(TIMELIMIT)$(ROOT)/chain > $(ROOT)/chain.output
	@rm -f $(ROOT)/chain.output
	@touch $@

$(ROOT)/winstack.done: $(ROOT)/winstack$(DOTEXE)
	@echo Testing winstack
	$(TIMELIMIT)$< $(RUN_ARGS)
	@touch $@

$(ROOT)/stderr_msg.done: stderr_exp="stderr_msg msg"
$(ROOT)/unittest_assert.done: stderr_exp="unittest_assert msg"
$(ROOT)/invalid_memory_operation.done: stderr_exp="InvalidMemoryOperationError"
$(ROOT)/unknown_gc.done: stderr_exp="'unknowngc'"
$(ROOT)/static_dtor.done: stderr_exp="dtor_called_more_than_once"
$(ROOT)/static_dtor.done: private negate=!
$(ROOT)/future_message.done: stderr_exp="exception I have a custom message. exception exception "
$(ROOT)/catch_in_finally.done: stderr_exp="success."
$(ROOT)/rt_trap_exceptions.done: stderr_exp="object.Exception@src/rt_trap_exceptions.d(12): this will abort"
$(ROOT)/rt_trap_exceptions.done: stderr_exp2="src/rt_trap_exceptions.d:8 main"
$(ROOT)/assert_fail.done: stderr_exp="success."
$(ROOT)/cpp_demangle.done: stderr_exp="thrower(int)"
$(ROOT)/message_with_null.done: stderr_exp=" world"
$(ROOT)/memoryerror_null_read.done: stderr_exp="segmentation fault: null pointer read/write operation"
$(ROOT)/memoryerror_null_write.done: stderr_exp="segmentation fault: null pointer read/write operation"
$(ROOT)/memoryerror_null_call.done: stderr_exp="segmentation fault: null pointer read/write operation"
$(ROOT)/memoryerror_null_call.done: stderr_exp2="uncaught exception reached top of stack"
$(ROOT)/memoryerror_stackoverflow.done: stderr_exp="segmentation fault: call stack overflow"

$(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(TIMELIMIT)$< $(run_args) 2>$(ROOT)/$*.stderr || true

	@if $(negate) grep -qF $(stderr_exp) $(ROOT)/$*.stderr ; then true ; else  \
		echo 'Searched for pattern $(stderr_exp), NEGATE = $(negate)' ;\
		tail --bytes=5000 $(ROOT)/$*.stderr ;\
		exit 1 ;\
	fi
	@if [ ! -z $(stderr_exp2) ] ; then \
		if $(negate) grep -qF $(stderr_exp2) $(ROOT)/$*.stderr ; then true ; else \
			echo 'Searched for '$(stderr_exp2)' NEGATE = $(negate)' ;\
			tail --bytes=5000 $(ROOT)/$*.stderr ;\
			exit 1 ;\
		fi \
	fi
	@touch $@

$(ROOT)/rt_trap_exceptions_drt.done: stderr_exp="uncaught exception\nobject.Exception@rt_trap_exceptions_drt.d(4): exception"
$(ROOT)/rt_trap_exceptions_drt.done: run_args="--DRT-trapExceptions=0"
$(ROOT)/rt_trap_exceptions_drt.done: negate=!

$(ROOT)/rt_trap_exceptions_drt_gdb.done: $(ROOT)/rt_trap_exceptions_drt$(DOTEXE)
	@echo Testing rt_trap_exceptions_drt_gdb
	$(TIMELIMIT) $(GDB) -n -ex 'set confirm off' -ex run -ex 'bt full' -ex q --args $< --DRT-trapExceptions=0 \
		> $(ROOT)/rt_trap_exceptions_drt_gdb.output 2>&1 || true
	cat $(ROOT)/rt_trap_exceptions_drt_gdb.output
	grep "\(D main\|_Dmain\) (args=...) at .*rt_trap_exceptions_drt.d:9" > /dev/null < $(ROOT)/rt_trap_exceptions_drt_gdb.output
	grep 'myLocal' > /dev/null < $(ROOT)/rt_trap_exceptions_drt_gdb.output
	! grep "No stack." > /dev/null < $(ROOT)/rt_trap_exceptions_drt_gdb.output
	@touch $@

$(ROOT)/refcounted.done: $(ROOT)/refcounted$(DOTEXE)
	@echo Testing $(<F:$(DOTEXE)=)
	$<
	@touch $@

ifneq (,$(findstring ldmd,$(DMD)))
# LDC: Make sure allocation intended to provoke exception is not elided.
$(ROOT)/invalid_memory_operation$(DOTEXE): extra_dflags+=-disable-gc2stack
endif
$(ROOT)/unittest_assert$(DOTEXE): extra_dflags += -unittest -version=CoreUnittest
$(ROOT)/line_trace$(DOTEXE): extra_dflags += -g
$(ROOT)/line_trace$(DOTEXE): extra_ldflags.d += $(line_trace_dflags)
$(ROOT)/long_backtrace_trunc$(DOTEXE): extra_dflags += -g
$(ROOT)/long_backtrace_trunc$(DOTEXE): extra_ldflags.d += $(line_trace_dflags)
$(ROOT)/rt_trap_exceptions$(DOTEXE): extra_dflags += -g
$(ROOT)/rt_trap_exceptions$(DOTEXE): extra_ldflags.d += $(line_trace_dflags)
$(ROOT)/rt_trap_exceptions_drt$(DOTEXE): extra_dflags += -g
$(ROOT)/refcounted$(DOTEXE): extra_dflags+=-dip1008
$(ROOT)/cpp_demangle$(DOTEXE): extra_ldflags.d+=$(line_trace_dflags)
$(ROOT)/cpp_demangle$(DOTEXE): extra_ldlibs.d+=-L-lstdc++
