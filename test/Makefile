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
ifeq (Win_32_64,$(OS))
    OS:=win64
    MODEL:=64
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

# List the tests that take longest to run first, so that parallel make
# will test them sooner, because they are large, have many test
# permutations, or typically are the last tests to finish.
runnable_tests_long=runnable/test42.d \
		    runnable/xtest46.d \
		    runnable/test34.d \
		    runnable/test23.d \
		    runnable/hospital.d \
		    runnable/testsignals.d \
		    runnable/interpret.d

runnable_tests=$(runnable_tests_long) $(wildcard runnable/*.d) $(wildcard runnable/*.sh)
runnable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(runnable_tests)))

compilable_tests=$(wildcard compilable/*.d) $(wildcard compilable/*.sh)
compilable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(compilable_tests)))

fail_compilation_tests=$(wildcard fail_compilation/*.d) $(wildcard fail_compilation/*.sh) $(wildcard fail_compilation/*.html)
fail_compilation_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(fail_compilation_tests)))

all: run_tests

test_tools=$(RESULTS_DIR)/d_do_test$(EXE) $(RESULTS_DIR)/sanitize_json$(EXE)

$(RESULTS_DIR)/%.out: % $(RESULTS_DIR)/.created $(test_tools) $(DMD)
	$(QUIET) $(RESULTS_DIR)/d_do_test $<

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

run_tests: unit_tests start_runnable_tests start_compilable_tests start_fail_compilation_tests

unit_tests: $(RESULTS_DIR)/unit_test_runner$(EXE)
	@echo "Running unit tests"
	$<

run_runnable_tests: $(runnable_test_results)

start_runnable_tests: $(RESULTS_DIR)/.created $(test_tools)
	@echo "Running runnable tests"
	$(QUIET)$(MAKE) --no-print-directory run_runnable_tests

run_compilable_tests: $(compilable_test_results)

start_compilable_tests: $(RESULTS_DIR)/.created $(test_tools)
	@echo "Running compilable tests"
	$(QUIET)$(MAKE) --no-print-directory run_compilable_tests

run_fail_compilation_tests: $(fail_compilation_test_results)

start_fail_compilation_tests: $(RESULTS_DIR)/.created $(test_tools)
	@echo "Running fail compilation tests"
	$(QUIET)$(MAKE) --no-print-directory run_fail_compilation_tests

$(RESULTS_DIR)/d_do_test$(EXE): tools/d_do_test.d $(RESULTS_DIR)/.created
	@echo "Building d_do_test tool"
	@echo "OS: '$(OS)'"
	@echo "MODEL: '$(MODEL)'"
	@echo "PIC: '$(PIC_FLAG)'"
	$(DMD) -conf= $(MODEL_FLAG) $(DEBUG_FLAGS) -unittest -run $<
	$(DMD) -conf= $(MODEL_FLAG) $(DEBUG_FLAGS) -od$(RESULTS_DIR) -of$(RESULTS_DIR)$(DSEP)d_do_test$(EXE) $<

$(RESULTS_DIR)/sanitize_json$(EXE): tools/sanitize_json.d $(RESULTS_DIR)/.created
	@echo "Building sanitize_json tool"
	@echo "OS: '$(OS)'"
	@echo "MODEL: '$(MODEL)'"
	@echo "PIC: '$(PIC_FLAG)'"
	$(DMD) -conf= $(MODEL_FLAG) $(DEBUG_FLAGS) -od$(RESULTS_DIR) -of$(RESULTS_DIR)$(DSEP)sanitize_json$(EXE) -i $<

$(RESULTS_DIR)/unit_test_runner$(EXE): tools/unit_test_runner.d $(RESULTS_DIR)/.created | $(DMD)
	@echo "Building unit_test_runner tool"
	@echo "OS: '$(OS)'"
	@echo "MODEL: '$(MODEL)'"
	@echo "PIC: '$(PIC_FLAG)'"
	$(DMD) -conf= $(MODEL_FLAG) $(DEBUG_FLAGS) -od$(RESULTS_DIR) -of$(RESULTS_DIR)$(DSEP)unit_test_runner$(EXE) -i $<
