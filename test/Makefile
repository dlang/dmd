# Execute the dmd test suite
#
# Targets:
#    default | all:      run all unit tests that haven't been run yet
#
#    run_tests:          run all tests
#    run_runnable_tests: run just the runnable tests
#
#    clean:              remove any temporary or result files from prevous runs
#
#
# In-test variables:
#   REQUIRED_ARGS:       arguments to add to the $(DMD) command line
#                        default: (none)
#   PERMUTE_ARGS:        the set of arguments to permute in multiple $(DMD) invocations
#                        default: the make variable ARGS (see below)
#
# NOTE: the bash scripting below fails if the .d file has dos style line endings

SHELL=/bin/bash
DMD=../src/dmd
RESULTS_DIR=test_results
QUIET=@

ARGS=-inline -release -gc -O -unittest -fPIC
#ARGS=-inline

runnable_tests=$(wildcard runnable/*.d)
runnable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(runnable_tests)))

$(RESULTS_DIR)/%.d.out: %.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) \
	rm -f $@; \
	r_args=`grep REQUIRED_ARGS $<`; \
	p_args=`grep PERMUTE_ARGS  $<`; \
	if [ ! -z "$$r_args" ]; then r_args="$${r_args/*REQUIRED_ARGS:/}"; fi; \
	if [ -z "$$p_args" ]; then p_args="$(ARGS)"; else p_args="$${p_args/*PERMUTE_ARGS:/}"; fi; \
	echo -e " ... $<  required: $$r_args\tpermuted args: $$p_args"; \
	$(RESULTS_DIR)/combinations $$p_args | while read x; do \
	    echo "dmd args: $$r_args $$x" >> $@; \
	    $(DMD) $$r_args $$x -od$(RESULTS_DIR)/$(*D) -of$(RESULTS_DIR)/$* $<; \
	    if [ $$? -ne 0 ]; then break; fi; \
	    $(RESULTS_DIR)/$* >> $@ 2>&1 && rm $(RESULTS_DIR)/$* $(RESULTS_DIR)/$*.o; \
	    if [ $$? -ne 0 ]; then break; fi; \
	    echo >> $@; \
       	done

all: run_tests

clean:
	@echo "Removing output directory: $(RESULTS_DIR)"
	$(QUIET)if [ -e $(RESULTS_DIR) ]; then rm -rf $(RESULTS_DIR); fi

$(RESULTS_DIR)/.created:
	@echo Creating output directory: $(RESULTS_DIR) 
	$(QUIET)if [ ! -d $(RESULTS_DIR) ]; then mkdir $(RESULTS_DIR); fi
	$(QUIET)if [ ! -d $(RESULTS_DIR)/runnable ]; then mkdir $(RESULTS_DIR)/runnable; fi
	$(QUIET)touch $(RESULTS_DIR)/.created

run_tests: start_runnable_tests

run_runnable_tests: $(runnable_test_results)

start_runnable_tests: $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations
	@echo "Running runnable tests"
	$(QUIET)$(MAKE) --no-print-directory run_runnable_tests

$(RESULTS_DIR)/combinations: combinations.d $(RESULTS_DIR)/.created
	@echo "Building combinations tool"
	$(QUIET)dmd -od$(RESULTS_DIR) -of$(RESULTS_DIR)/combinations combinations.d
