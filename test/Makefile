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

compilable_tests=$(wildcard compilable/*.d)
compilable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(compilable_tests)))

fail_compilation_tests=$(wildcard fail_compilation/*.d)
fail_compilation_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(fail_compilation_tests)))

$(RESULTS_DIR)/runnable/%.d.out: runnable/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) \
	rm -f $@; \
	t=$(@D)/$*; \
	r_args=`grep REQUIRED_ARGS $<`; \
	p_args=`grep PERMUTE_ARGS  $<`; \
	if [ ! -z "$$r_args" ]; then r_args="$${r_args/*REQUIRED_ARGS:/}"; fi; \
	if [ -z "$$p_args" ]; then p_args="$(ARGS)"; else p_args="$${p_args/*PERMUTE_ARGS:/}"; fi; \
	echo -e " ... $<  required: $$r_args\tpermuted args: $$p_args"; \
	$(RESULTS_DIR)/combinations $$p_args | while read x; do \
	    echo "dmd args: $$r_args $$x" >> $@; \
	    $(DMD) $$r_args $$x -od$(@D) -of$$t $<; \
	    if [ $$? -ne 0 ]; then exit 1; fi; \
	    $$t >> $@ 2>&1 && rm $$t $$t.o; \
	    if [ $$? -ne 0 ]; then exit 1; fi; \
	    echo >> $@; \
       	done

$(RESULTS_DIR)/compilable/%.d.out: compilable/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) \
	rm -f $@; \
	t=$(@D)/$*; \
	r_args=`grep REQUIRED_ARGS $<`; \
	p_args=`grep PERMUTE_ARGS  $<`; \
	if [ ! -z "$$r_args" ]; then r_args="$${r_args/*REQUIRED_ARGS:/}"; fi; \
	if [ -z "$$p_args" ]; then p_args="$(ARGS)"; else p_args="$${p_args/*PERMUTE_ARGS:/}"; fi; \
	echo -e " ... $<  required: $$r_args\tpermuted args: $$p_args"; \
	$(RESULTS_DIR)/combinations $$p_args | while read x; do \
	    echo "dmd args: $$r_args $$x" >> $@; \
	    $(DMD) -c $$r_args $$x -od$(@D) -of$$t.o $<; \
	    if [ $$? -ne 0 ]; then exit 1; fi; \
	    rm -f $$t.o; \
	    echo >> $@; \
       	done

$(RESULTS_DIR)/fail_compilation/%.d.out: fail_compilation/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) \
	rm -f $@; \
	t=$(@D)/$*; \
	r_args=`grep REQUIRED_ARGS $<`; \
	p_args=`grep PERMUTE_ARGS  $<`; \
	if [ ! -z "$$r_args" ]; then r_args="$${r_args/*REQUIRED_ARGS:/}"; fi; \
	if [ -z "$$p_args" ]; then p_args="$(ARGS)"; else p_args="$${p_args/*PERMUTE_ARGS:/}"; fi; \
	echo -e " ... $<  required: $$r_args\tpermuted args: $$p_args"; \
	$(RESULTS_DIR)/combinations $$p_args | while read x; do \
	    echo "dmd args: $$r_args $$x" >> $@; \
	    $(DMD) -c $$r_args $$x -od$(@D) -of$$t.o $< 2>/dev/null; \
	    if [ $$? -eq 0 ]; then rm -f $$t.o; echo "$< should have failed to compile but succeeded instead"; exit 1; break; fi; \
	    echo >> $@; \
       	done

all: run_tests

debug:
	@echo "runnable_tests: $(runnable_tests)"
	@echo "compilable_tests: $(compilable_tests)"
	@echo "fail_compilation_tests: $(fail_compilation_tests)"
	@echo "runnable_test_results: $(runnable_test_results)"
	@echo "compilable_test_results: $(compilable_test_results)"
	@echo "fail_compilation_test_results: $(fail_compilation_test_results)"

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
	$(QUIET)dmd -od$(RESULTS_DIR) -of$(RESULTS_DIR)/combinations combinations.d
