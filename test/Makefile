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
#   POST_SCRIPT:         name of script to execute after test run
#                        default: (none)
#
#   REQUIRED_ARGS:       arguments to add to the $(DMD) command line
#                        default: (none)

SHELL=/bin/bash
QUIET=@
export DMD=../src/dmd
export RESULTS_DIR=test_results
export ARGS=-inline -release -gc -O -unittest -fPIC

runnable_tests=$(wildcard runnable/*.d) $(wildcard runnable/*.html) $(wildcard runnable/*.sh)
runnable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(runnable_tests)))

compilable_tests=$(wildcard compilable/*.d)
compilable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(compilable_tests)))

fail_compilation_tests=$(wildcard fail_compilation/*.d)
fail_compilation_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(fail_compilation_tests)))

$(RESULTS_DIR)/runnable/%.d.out: runnable/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) ./do_test.sh $(<D) $* d

$(RESULTS_DIR)/runnable/%.html.out: runnable/%.html $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) ./do_test.sh $(<D) $* html

$(RESULTS_DIR)/runnable/%.sh.out: runnable/%.sh $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) echo " ... $(<D)/$*.sh"
	$(QUIET) ./$(<D)/$*.sh

$(RESULTS_DIR)/compilable/%.d.out: compilable/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) ./do_test.sh $(<D) $* d

$(RESULTS_DIR)/fail_compilation/%.d.out: fail_compilation/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) ./do_test.sh $(<D) $* d

all: run_tests

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

start_runnable_tests: $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations
	@echo "Running runnable tests"
	$(QUIET)$(MAKE) --no-print-directory run_runnable_tests

run_compilable_tests: $(compilable_test_results)

start_compilable_tests: $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations
	@echo "Running compilable tests"
	$(QUIET)$(MAKE) --no-print-directory run_compilable_tests

run_fail_compilation_tests: $(fail_compilation_test_results)

start_fail_compilation_tests: $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations
	@echo "Running fail compilation tests"
	$(QUIET)$(MAKE) --no-print-directory run_fail_compilation_tests

$(RESULTS_DIR)/combinations: combinations.d $(RESULTS_DIR)/.created
	@echo "Building combinations tool"
	$(QUIET)$(DMD) -od$(RESULTS_DIR) -of$(RESULTS_DIR)/combinations combinations.d
