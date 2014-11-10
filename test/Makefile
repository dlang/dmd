# Execute the dmd test suite
#
# Targets:
#
#    default | all:      run all unit tests that haven't been run yet
#
#    run_tests:          run all tests
#    run_runnable_tests:         run just the runnable tests
#    run_compilable_tests:       run just the runnable tests
#    run_fail_compilation_tests: run just the runnable tests
#
#    quick:              run all tests with no default permuted args
#                        (individual test specified options still honored)
#
#    clean:              remove all temporary or result files from prevous runs
#
#
# In-test variables:
#
#   COMPILE_SEPARATELY:  if present, forces each .d file to compile separately and linked
#                        together in an extra setp.
#                        default: (none, aka compile/link all in one step)
#
#   EXECUTE_ARGS:        parameters to add to the execution of the test
#                        default: (none)
#
#   EXTRA_SOURCES:       list of extra files to build and link along with the test
#                        default: (none)
#
#   PERMUTE_ARGS:        the set of arguments to permute in multiple $(DMD) invocations
#                        default: the make variable ARGS (see below)
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

ifeq (,$(OS))
    OS:=$(shell uname)
    ifeq (Darwin,$(OS))
        OS:=osx
    else
        ifeq (Linux,$(OS))
            OS:=linux
        else
            ifeq (FreeBSD,$(OS))
                OS:=freebsd
            else
                $(error Unrecognized or unsupported OS for uname: $(OS))
            endif
        endif
    endif
else
    ifeq (Windows_NT,$(OS))
        ifeq ($(findstring WOW64, $(shell uname)),WOW64)
            OS:=win64
        else
            OS:=win32
        endif
    endif
    ifeq (Win_32,$(OS))
	OS:=win32
    endif
    ifeq (Win_64,$(OS))
	OS:=win64
    endif
endif
export OS

ifeq (freebsd,$(OS))
    SHELL=/usr/local/bin/bash
else
    SHELL=/bin/bash
endif
QUIET=@
export RESULTS_DIR=test_results
export MODEL=32
export REQUIRED_ARGS=

ifeq ($(findstring win,$(OS)),win)
export ARGS=-inline -release -g -O -unittest
export DMD=../src/dmd.exe
export EXE=.exe
export OBJ=.obj
export DSEP=\\
export SEP=$(subst /,\,/)
else
export ARGS=-inline -release -gc -O -unittest -fPIC
export DMD=../src/dmd
export EXE=
export OBJ=.o
export DSEP=/
export SEP=/
endif

ifeq ($(OS),freebsd)
DISABLED_TESTS += builtin
# precision related bug: Error: static assert  (0x1.f9f8d9aea10fb28ep-2L == 0x1.f9f8d9aea10fdf1cp-2L) is false

DISABLED_TESTS += dhry
# runnable/dhry.d(488): Error: undefined identifier dtime

# 64 bit test failures
DISABLED_TESTS += test17
DISABLED_SH_TESTS += test39
endif

ifeq ($(OS),win64)
DISABLED_TESTS += testargtypes
DISABLED_TESTS += testxmm
endif

ifeq ($(OS),osx)
ifeq ($(MODEL),64)
DISABLED_TESTS += test6423
endif
endif

runnable_tests=$(wildcard runnable/*.d) $(wildcard runnable/*.sh)
runnable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(runnable_tests)))

compilable_tests=$(wildcard compilable/*.d) $(wildcard compilable/*.sh)
compilable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(compilable_tests)))

fail_compilation_tests=$(wildcard fail_compilation/*.d) $(wildcard fail_compilation/*.html)
fail_compilation_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(fail_compilation_tests)))

all: run_tests

$(addsuffix .d.out,$(addprefix $(RESULTS_DIR)/runnable/,$(DISABLED_TESTS))): $(RESULTS_DIR)/.created
	$(QUIET) echo " ... $@ - disabled"

$(addsuffix .sh.out,$(addprefix $(RESULTS_DIR)/runnable/,$(DISABLED_SH_TESTS))): $(RESULTS_DIR)/.created
	$(QUIET) echo " ... $@ - disabled"

$(RESULTS_DIR)/runnable/%.d.out: runnable/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE) $(DMD)
	$(QUIET) $(RESULTS_DIR)/d_do_test $(<D) $* d

$(RESULTS_DIR)/runnable/%.sh.out: runnable/%.sh $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE) $(DMD)
	$(QUIET) echo " ... $(<D)/$*.sh"
	$(QUIET) ./$(<D)/$*.sh

$(RESULTS_DIR)/compilable/%.d.out: compilable/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE) $(DMD)
	$(QUIET) $(RESULTS_DIR)/d_do_test $(<D) $* d

$(RESULTS_DIR)/compilable/%.sh.out: compilable/%.sh $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE) $(DMD)
	$(QUIET) echo " ... $(<D)/$*.sh"
	$(QUIET) ./$(<D)/$*.sh

$(RESULTS_DIR)/fail_compilation/%.d.out: fail_compilation/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE) $(DMD)
	$(QUIET) $(RESULTS_DIR)/d_do_test $(<D) $* d

$(RESULTS_DIR)/fail_compilation/%.html.out: fail_compilation/%.html $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE) $(DMD)
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

start_runnable_tests: $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE)
	@echo "Running runnable tests"
	$(QUIET)$(MAKE) --no-print-directory run_runnable_tests

run_compilable_tests: $(compilable_test_results)

start_compilable_tests: $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE)
	@echo "Running compilable tests"
	$(QUIET)$(MAKE) --no-print-directory run_compilable_tests

run_fail_compilation_tests: $(fail_compilation_test_results)

start_fail_compilation_tests: $(RESULTS_DIR)/.created $(RESULTS_DIR)/d_do_test$(EXE)
	@echo "Running fail compilation tests"
	$(QUIET)$(MAKE) --no-print-directory run_fail_compilation_tests

$(RESULTS_DIR)/d_do_test$(EXE): d_do_test.d $(RESULTS_DIR)/.created
	@echo "Building d_do_test tool"
	@echo "OS: $(OS)"
	$(QUIET)$(DMD) -m$(MODEL) -unittest -run d_do_test.d -unittest
	$(QUIET)$(DMD) -m$(MODEL) -od$(RESULTS_DIR) -of$(RESULTS_DIR)$(DSEP)d_do_test$(EXE) d_do_test.d

