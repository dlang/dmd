# Execute the dmd test suite
#
# Targets:
#
#    default | all:      run all unit tests that haven't been run yet
#
#    run_tests:          run all tests
#    run_runnable_tests: run just the runnable tests
#
#    clean:              remove any temporary or result files from prevous runs
#
#
# In-test variables:
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
#   REQUIRED_ARGS:       arguments to add to the $(DMD) command line
#                        default: (none)

SHELL=/bin/bash
DMD=../src/dmd
RESULTS_DIR=test_results
QUIET=@

ARGS=-inline -release -gc -O -unittest -fPIC

runnable_tests=$(wildcard runnable/*.d)
runnable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(runnable_tests)))

compilable_tests=$(wildcard compilable/*.d)
compilable_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(compilable_tests)))

fail_compilation_tests=$(wildcard fail_compilation/*.d)
fail_compilation_test_results=$(addsuffix .out,$(addprefix $(RESULTS_DIR)/,$(fail_compilation_tests)))

$(RESULTS_DIR)/runnable/%.d.out: runnable/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) \
	shopt -s extglob; \
	rm -f $@; \
	t=$(@D)/$*; \
	r_args=`grep REQUIRED_ARGS $< | tr -d \\\\r\\\\n`; \
	p_args=`grep PERMUTE_ARGS  $< | tr -d \\\\r\\\\n`; \
	e_args=`grep EXECUTE_ARGS  $< | tr -d \\\\r\\\\n`; \
	extra_sources=`grep EXTRA_SOURCES $< | tr -d \\\\r\\\\n`; \
	if [ ! -z "$$r_args" ]; then r_args="$${r_args/*REQUIRED_ARGS:*( )/}"; fi; \
	if [ -z "$$p_args" ]; then p_args="$(ARGS)"; else p_args="$${p_args/*PERMUTE_ARGS:*( )/}"; fi; \
	if [ ! -z "$$e_args" ]; then e_args="$${e_args/*EXECUTE_ARGS:*( )/}"; fi; \
	if [ ! -z "$$extra_sources" ]; then extra_sources=($${extra_sources/*EXTRA_SOURCES:*( )/}); fi; \
	printf " ... %-30s required: %-5s permuted args: %s\n" "$<" "$$r_args" "$$p_args"; \
	$(RESULTS_DIR)/combinations $$p_args | while read x; do \
	    echo "dmd args: $$r_args $$x" >> $@; \
	    $(DMD) -I$(<D) $$r_args $$x -od$(@D) -of$$t $< $${extra_sources[*]/imports/runnable\/imports}; \
	    if [ $$? -ne 0 ]; then rm -f $$t.d.out; exit 1; fi; \
	    $$t $$e_args >> $@ 2>&1; \
	    if [ $$? -ne 0 ]; then cat $@; rm -f $$t $$t.o $@; exit 1; fi; \
	    rm -f $$t $$t.o; \
	    echo >> $@; \
       	done

$(RESULTS_DIR)/compilable/%.d.out: compilable/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) \
	shopt -s extglob; \
	rm -f $@; \
	t=$(@D)/$*; \
	r_args=`grep REQUIRED_ARGS $< | tr -d \\\\r\\\\n`; \
	p_args=`grep PERMUTE_ARGS  $< | tr -d \\\\r\\\\n`; \
	if [ ! -z "$$r_args" ]; then r_args="$${r_args/*REQUIRED_ARGS:*( )/}"; fi; \
	if [ -z "$$p_args" ]; then p_args="$(ARGS)"; else p_args="$${p_args/*PERMUTE_ARGS:*( )/}"; fi; \
	printf " ... %-30s required: %-5s permuted args: %s\n" "$<" "$$r_args" "$$p_args"; \
	$(RESULTS_DIR)/combinations $$p_args | while read x; do \
	    echo "dmd args: $$r_args $$x" >> $@; \
	    $(DMD) -I$(<D) $$r_args $$x -od$(@D) -of$$t.o -c $<; \
	    if [ $$? -ne 0 ]; then exit 1; fi; \
	    rm -f $$t.o; \
	    echo >> $@; \
       	done

$(RESULTS_DIR)/fail_compilation/%.d.out: fail_compilation/%.d $(RESULTS_DIR)/.created $(RESULTS_DIR)/combinations $(DMD)
	$(QUIET) \
	shopt -s extglob; \
	rm -f $@; \
	t=$(@D)/$*; \
	r_args=`grep REQUIRED_ARGS $< | tr -d \\\\r\\\\n`; \
	p_args=`grep PERMUTE_ARGS  $< | tr -d \\\\r\\\\n`; \
	if [ ! -z "$$r_args" ]; then r_args="$${r_args/*REQUIRED_ARGS:*( )/}"; fi; \
	if [ -z "$$p_args" ]; then p_args="$(ARGS)"; else p_args="$${p_args/*PERMUTE_ARGS:*( )/}"; fi; \
	printf " ... %-30s required: %-5s permuted args: %s\n" "$<" "$$r_args" "$$p_args"; \
	$(RESULTS_DIR)/combinations $$p_args | while read x; do \
	    echo "dmd args: $$r_args $$x" >> $@; \
	    $(DMD) -I$(<D) $$r_args $$x -od$(@D) -of$$t.o -c $< 2> /dev/null; \
	    if [ $$? -eq 0 ]; then rm -f $$t.o; echo "$< should have failed to compile but succeeded instead"; exit 1; break; fi; \
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
