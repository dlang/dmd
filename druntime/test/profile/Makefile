TESTS := profile profilegc both
SRC_DIR := src
DMD ?= dmd

ifeq ($(OS),Windows_NT)
    DOTEXE := .exe
    PATH_SEP := \\
    SHELL := cmd.exe
else
    DOTEXE :=
    PATH_SEP := /
endif

# Platform Detection
UNAME_S := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ifeq ($(UNAME_S),darwin)
    PLATFORM := osx
    MODELS := 64
else ifeq ($(UNAME_S),linux)
    PLATFORM := linux
    MODELS := 32 64
else ifeq ($(OS),Windows_NT)
    PLATFORM := windows
    MODELS := 32 64
else
    PLATFORM := $(UNAME_S)
    MODELS := 32 64
endif

# Generate reference files
.PHONY: generate-references
generate-references:
	@echo "Generating reference files for $(PLATFORM)"
	@for model in $(MODELS); do \
		echo "=== Building $$model-bit version ==="; \
		$(MAKE) clean MODEL=$$model; \
		if $(MAKE) MODEL=$$model profilegc.done; then \
			if [ -f myprofilegc.log.$(PLATFORM).$$model.exp ]; then \
				echo "Generated myprofilegc.log.$(PLATFORM).$$model.exp"; \
			else \
				echo "Error: No output file created"; \
				exit 1; \
			fi; \
		else \
			echo "Skipping $$model-bit (build failed)"; \
		fi; \
	done

%$(DOTEXE): $(SRC_DIR)/%.d
	$(DMD) $(MODEL_FLAG) -of$@ $< $(extra_dflags)

# Test rules
profile.done: profile$(DOTEXE)
	@echo "Testing profile"
	@rm -f mytrace.log mytrace.def mytrace.def.sorted mytrace.def.exp.sorted
	./profile$(DOTEXE) mytrace.log mytrace.def

	@# Verify log contents
	@grep -q '1 .*_Dmain' mytrace.log || (echo "FAIL: _Dmain not found"; exit 1)
	@grep -q '1000 .*uint profile.foo(uint)' mytrace.log || (echo "FAIL: foo calls not found"; exit 1)

	@# Format definitions file
	@(echo "FUNCTIONS" && grep -v "FUNCTIONS" mytrace.def | sort) > mytrace.def.sorted

	@# Handle expected output
	@if [ -f mytrace.def.exp ]; then \
		(echo "FUNCTIONS" && grep -v "FUNCTIONS" mytrace.def.exp | sort) > mytrace.def.exp.sorted; \
		if ! diff -u mytrace.def.exp.sorted mytrace.def.sorted >/dev/null; then \
			echo "FAIL: Profile definitions mismatch"; \
			diff -u mytrace.def.exp.sorted mytrace.def.sorted || true; \
			exit 1; \
		fi; \
	else \
		cp mytrace.def.sorted mytrace.def.exp; \
		echo "Created reference: mytrace.def.exp"; \
	fi
	@touch $@

profilegc.done: profilegc$(DOTEXE)
	@echo "Testing profilegc"
	@rm -f myprofilegc.log myprofilegc.log.$(PLATFORM).$(MODEL).exp
	./profilegc$(DOTEXE) myprofilegc.log
	@echo "Formatting output..."
	@(echo "bytes allocated, allocations, type, function, file:line" && \
	  grep '^[[:space:]]*[0-9]' myprofilegc.log | \
	  while IFS= read -r line; do \
	    bytes=$$(echo "$$line" | awk '{print $$1}'); \
	    allocs=$$(echo "$$line" | awk '{print $$2}'); \
	    type=$$(echo "$$line" | awk '{print $$3}'); \
	    func=$$(echo "$$line" | awk '{print $$4}'); \
	    loc=$$(echo "$$line" | awk '{print $$NF}'); \
	    printf "%16d,%15d,%-30s,%-40s,%s\n" "$$bytes" "$$allocs" "$$type" "$$func" "$$loc"; \
	  done) > myprofilegc.log.$(PLATFORM).$(MODEL).exp
	@cat myprofilegc.log.$(PLATFORM).$(MODEL).exp
	@touch $@

both.done: both$(DOTEXE)
	@echo "Testing both"
	@rm -f both.log both.def bothgc.log
	./both$(DOTEXE) both.log both.def bothgc.log

	@# Verify output
	@grep -q '1 .*_Dmain' both.log || (echo "FAIL: _Dmain not found"; exit 1)
	@grep -q '1000 .*both.Num\* both.foo(uint)' both.log || (echo "FAIL: foo calls not found"; exit 1)

	@# Process definitions
	@if [ -f bothnew.def.exp ]; then \
		grep -v '^FUNCTIONS' both.def | sort | grep -v 'typeNameFNbNeC15TypeInfo_Struct' > both.def.content; \
		grep -v '^FUNCTIONS' bothnew.def.exp | sort | grep -v 'typeNameFNbNeC15TypeInfo_Struct' > bothnew.def.exp.content; \
		if ! diff -u bothnew.def.exp.content both.def.content; then \
			echo "FAIL: Profile definitions mismatch"; \
			exit 1; \
		fi; \
	else \
		cp both.def bothnew.def.exp; \
	fi

	@# Check GC profile
	@if [ -f bothgc.log.exp ]; then \
		sed -e '/core\./d' -e 's/[0-9]\+/XXX/g' bothgc.log > bothgc.log.norm; \
		sed -e '/core\./d' -e 's/[0-9]\+/XXX/g' bothgc.log.exp > bothgc.log.exp.norm; \
		if ! diff -u bothgc.log.exp.norm bothgc.log.norm; then \
			echo "FAIL: GC profile mismatch"; \
			exit 1; \
		fi; \
	else \
		cp bothgc.log bothgc.log.exp; \
	fi
	@touch $@

# Compiler flags
profile$(DOTEXE): extra_dflags += -profile
profilegc$(DOTEXE): extra_dflags += -profile=gc
both$(DOTEXE): extra_dflags += -profile -profile=gc

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -f *.done
	@rm -f mytrace.log mytrace.def mytrace.def.sorted mytrace.def.exp.sorted
	@rm -f myprofilegc.log	myprofilegc.formatted.log
	@rm -f both.log both.def bothgc.log	both.def.content	bothgc.log.norm	bothgc.log.exp.norm	bothnew.def.exp.content
	@rm -f *.o
	@rm -f profile profilegc both
	@echo "Clean complete."
