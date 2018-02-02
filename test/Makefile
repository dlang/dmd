# Execute the dmd test suite
#
# Targets
# -------
#
#    default | all:      run all unit tests that haven't been run yet
#
#    run_tests:          run all tests
#    run_runnable_tests:         run just the runnable tests
#    run_compilable_tests:       run just the compilable tests
#    run_fail_compilation_tests: run just the fail compilation tests
#
#    quick:              run all tests with no default permuted args
#                        (individual test specified options still honored)
#
#    clean:              remove all temporary or result files from prevous runs
#
#    test_results/compilable/json.d.out      runs an individual test
#                                            (run log of the test is stored)

# In-test variables
# -----------------
#
#   COMPILE_SEPARATELY:  if present, forces each .d file to compile separately and linked
#                        together in an extra setp.
#                        default: (none, aka compile/link all in one step)
#
#   EXECUTE_ARGS:        parameters to add to the execution of the test
#                        default: (none)
#
#   COMPILED_IMPORTS:    list of modules files that are imported by the main source file that
#                        should be included in compilation; this differs from the EXTRA_SOURCES
#                        variable in that these files could be compiled by either explicitly
#                        passing them to the compiler or by using the "-i" option. Using this
#                        option will cause the test to be compiled twice, once using "-i" and
#                        once by explicitly passing the modules to the compiler.
#                        default: (none)
#
#   EXTRA_SOURCES:       list of extra files to build and link along with the test
#                        default: (none)
#
#   EXTRA_OBJC_SOURCES:  list of extra Objective-C files to build and link along with the test
#                        default: (none). Test files with this variable will be ignored unless
#                        the D_OBJC environment variable is set to "1"
#
#   PERMUTE_ARGS:        the set of arguments to permute in multiple $(DMD) invocations.
#                        An empty set means only one permutation with no arguments.
#                        default: the make variable ARGS (see below)
#
#   ARG_SETS:            sets off extra arguments to invoke $(DMD) with (seperated by ';').
#                        default: (none)
#
#   LINK:                enables linking (used for the compilable and fail_compilable tests).
#                        default: (none)
#
#   TEST_OUTPUT:         the output is expected from the compilation (if the
#                        output of the compilation doesn't match, the test
#                        fails). You can use the this format for multi-line
#                        output:
#                        TEST_OUTPUT:
#                        ---
#                        Some
#                        Output
#                        ---
#
#   POST_SCRIPT:         name of script to execute after test run
#                        note: arguments to the script may be included after the name.
#                              additionally, the name of the file that contains the output
#                              of the compile/link/run steps is added as the last parameter.
#                        default: (none)
#
#   REQUIRED_ARGS:       arguments to add to the $(DMD) command line
#                        default: (none)
#                        note: the make variable REQUIRED_ARGS is also added to the $(DMD)
#                              command line (see below)
#
#   DISABLED:            text describing why the test is disabled (if empty, the test is
#                        considered to be enabled).
#                        default: (none, enabled)

ifeq (Windows_NT,$(OS))
    ifeq ($(findstring WOW64, $(shell uname)),WOW64)
        OS:=win64
        MODEL:=64
    else
        OS:=win32
        MODEL:=32
    endif
endif
ifeq (Win_32,$(OS))
    OS:=win32
    MODEL:=32
endif
ifeq (Win_64,$(OS))
    OS:=win64
    MODEL:=64
endif

include ../src/osmodel.mak

export OS
BUILD=release

ifeq (freebsd,$(OS))
    SHELL=/usr/local/bin/bash
else ifeq (netbsd,$(OS))
    SHELL=/usr/pkg/bin/bash
else ifeq (dragonflybsd,$(OS))
    SHELL=/usr/local/bin/bash
else
    SHELL=/bin/bash
endif
QUIET=@
export RESULTS_DIR=test_results
export MODEL
export REQUIRED_ARGS=

ifeq ($(findstring win,$(OS)),win)
    export ARGS=-inline -release -g -O
    export EXE=.exe
    export OBJ=.obj
    export DSEP=\\
    export SEP=$(subst /,\,/)

    PIC?=0

    DRUNTIME_PATH=..\..\druntime
    PHOBOS_PATH=..\..\phobos
    export DFLAGS=-I$(DRUNTIME_PATH)\import -I$(PHOBOS_PATH)
    export LIB=$(PHOBOS_PATH)

    # auto-tester might run the testsuite with a different $(MODEL) than DMD
    # has been compiled with. Hence we manually check which binary exists.
    # For windows the $(OS) during build is: `windows`
    ifeq (,$(wildcard ../generated/windows/$(BUILD)/64/dmd$(EXE)))
        DMD_MODEL=32
    else
        DMD_MODEL=64
    endif
    export DMD=../generated/windows/$(BUILD)/$(DMD_MODEL)/dmd$(EXE)

else
    export ARGS=-inline -release -g -O -fPIC
    export EXE=
    export OBJ=.o
    export DSEP=/
    export SEP=/

    # auto-tester might run the testsuite with a different $(MODEL) than DMD
    # has been compiled with. Hence we manually check which binary exists.
    ifeq (,$(wildcard ../generated/$(OS)/$(BUILD)/64/dmd))
        DMD_MODEL=32
    else
        DMD_MODEL=64
    endif
    export DMD=../generated/$(OS)/$(BUILD)/$(DMD_MODEL)/dmd

    # default to PIC on x86_64, use PIC=1/0 to en-/disable PIC.
    # Note that shared libraries and C files are always compiled with PIC.
    ifeq ($(PIC),)
        ifeq ($(MODEL),64) # x86_64
            PIC:=1
        else
            PIC:=0
        endif
    endif
    ifeq ($(PIC),1)
        export PIC_FLAG:=-fPIC
    else
        export PIC_FLAG:=
    endif

    DRUNTIME_PATH=../../druntime
    PHOBOS_PATH=../../phobos
    # link against shared libraries (defaults to true on supported platforms, can be overridden w/ make SHARED=0)
    SHARED=$(if $(findstring $(OS),linux freebsd),1,)
    DFLAGS=-I$(DRUNTIME_PATH)/import -I$(PHOBOS_PATH) -L-L$(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL)
    ifeq (1,$(SHARED))
        DFLAGS+=-defaultlib=libphobos2.so -L-rpath=$(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL)
    endif
    export DFLAGS
endif
REQUIRED_ARGS+=$(PIC_FLAG)

ifeq ($(OS),osx)
    ifeq ($(MODEL),64)
        export D_OBJC=1
    endif
endif

DEBUG_FLAGS=$(PIC_FLAG) -g

export DMD_TEST_COVERAGE=

runnable_tests=$(wildcard runnable/*.d) $(wildcard runnable/*.sh)
runnable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(runnable_tests)))

compilable_tests=$(wildcard compilable/*.d) $(wildcard compilable/*.sh)
compilable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(compilable_tests)))

fail_compilation_tests=$(wildcard fail_compilation/*.d) $(wildcard fail_compilation/*.html)
fail_compilation_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(fail_compilation_tests)))

all: run_tests

test_tools: $(RESULTS_DIR)/d_do_test$(EXE) $(RESULTS_DIR)/sanitize_json$(EXE)

$(RESULTS_DIR)/runnable/%.d.out: runnable/%.d $(RESULTS_DIR)/.created test_tools $(DMD)
	$(QUIET) $(RESULTS_DIR)/d_do_test $(<D) $* d

$(RESULTS_DIR)/runnable/%.sh.out: runnable/%.sh $(RESULTS_DIR)/.created test_tools $(DMD)
	$(QUIET) echo " ... $(<D)/$*.sh"
	$(QUIET) ./$(<D)/$*.sh

$(RESULTS_DIR)/compilable/%.d.out: compilable/%.d $(RESULTS_DIR)/.created test_tools $(DMD)
	$(QUIET) $(RESULTS_DIR)/d_do_test $(<D) $* d

$(RESULTS_DIR)/compilable/%.sh.out: compilable/%.sh $(RESULTS_DIR)/.created test_tools $(DMD)
	$(QUIET) echo " ... $(<D)/$*.sh"
	$(QUIET) ./$(<D)/$*.sh

$(RESULTS_DIR)/fail_compilation/%.d.out: fail_compilation/%.d $(RESULTS_DIR)/.created test_tools $(DMD)
	$(QUIET) $(RESULTS_DIR)/d_do_test $(<D) $* d

$(RESULTS_DIR)/fail_compilation/%.html.out: fail_compilation/%.html $(RESULTS_DIR)/.created test_tools $(DMD)
	$(QUIET) $(RESULTS_DIR)/d_do_test $(<D) $* html

quick:
	$(MAKE) ARGS="" run_tests

clean:
	@echo "Removing output directory: $(RESULTS_DIR)"
	$(QUIET)if [ -e $(RESULTS_DIR) ]; then rm -rf $(RESULTS_DIR); fi

$(RESULTS_DIR)/.created:
	@echo Creating output directory: $(RESULTS_DIR)
	$(QUIET)if [ ! -d $(RESULTS_DIR) ]; then mkdir $(RESULTS_DIR); fi
	$(QUIET)if [ ! -d $(RESULTS_DIR)/runnable ]; then mkdir $(RESULTS_DIR)/runnable; fi
	$(QUIET)if [ ! -d $(RESULTS_DIR)/compilable ]; then mkdir $(RESULTS_DIR)/compilable; fi
	$(QUIET)if [ ! -d $(RESULTS_DIR)/fail_compilation ]; then mkdir $(RESULTS_DIR)/fail_compilation; fi
	$(QUIET)touch $(RESULTS_DIR)/.created

run_tests: start_runnable_tests start_compilable_tests start_fail_compilation_tests

run_runnable_tests: $(runnable_test_results)

start_runnable_tests: $(RESULTS_DIR)/.created test_tools
	@echo "Running runnable tests"
	$(QUIET)$(MAKE) --no-print-directory run_runnable_tests

run_compilable_tests: $(compilable_test_results)

start_compilable_tests: $(RESULTS_DIR)/.created test_tools
	@echo "Running compilable tests"
	$(QUIET)$(MAKE) --no-print-directory run_compilable_tests

run_fail_compilation_tests: $(fail_compilation_test_results)

start_fail_compilation_tests: $(RESULTS_DIR)/.created test_tools
	@echo "Running fail compilation tests"
	$(QUIET)$(MAKE) --no-print-directory run_fail_compilation_tests

$(RESULTS_DIR)/d_do_test$(EXE): d_do_test.d $(RESULTS_DIR)/.created
	@echo "Building d_do_test tool"
	@echo "OS: '$(OS)'"
	@echo "MODEL: '$(MODEL)'"
	@echo "PIC: '$(PIC_FLAG)'"
	$(DMD) -conf= $(MODEL_FLAG) $(DEBUG_FLAGS) -unittest -run d_do_test.d -unittest
	$(DMD) -conf= $(MODEL_FLAG) $(DEBUG_FLAGS) -od$(RESULTS_DIR) -of$(RESULTS_DIR)$(DSEP)d_do_test$(EXE) d_do_test.d

$(RESULTS_DIR)/sanitize_json$(EXE): sanitize_json.d $(RESULTS_DIR)/.created
	@echo "Building sanitize_json tool"
	@echo "OS: '$(OS)'"
	@echo "MODEL: '$(MODEL)'"
	@echo "PIC: '$(PIC_FLAG)'"
	$(DMD) -conf= $(MODEL_FLAG) $(DEBUG_FLAGS) -od$(RESULTS_DIR) -of$(RESULTS_DIR)$(DSEP)sanitize_json$(EXE) -i sanitize_json.d

