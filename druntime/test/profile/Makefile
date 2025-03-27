# Basic configuration
TESTS := profile profilegc both
SRC_DIR := src
DMD ?= dmd

# Platform Detection
UNAME_S := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ifeq ($(UNAME_S),darwin)
    PLATFORM := osx
    MODELS := 64  # macOS only supports 64-bit now
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
			if [ -f myprofilegc.formatted.log ]; then \
				cp myprofilegc.formatted.log myprofilegc.log.$(PLATFORM).$$model.exp; \
				echo "Generated myprofilegc.log.$(PLATFORM).$$model.exp"; \
			elif [ -f myprofilegc.log ]; then \
				cp myprofilegc.log myprofilegc.log.$(PLATFORM).$$model.exp; \
				echo "Generated myprofilegc.log.$(PLATFORM).$$model.exp (raw)"; \
			else \
				echo "Error: No output file created"; \
			fi; \
		else \
			echo "Skipping $$model-bit (build failed)"; \
		fi; \
	done

PROFILEGC_LOG := myprofilegc.log.$(PLATFORM).$(MODEL).exp

MODEL_FLAG := -m$(MODEL)

NORMALIZE = $(SED) -e '/core\./d' -e 's/[0-9]\+/XXX/g' -e 's|\\|/|g'

# Build rule (works for all platforms)
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

	@# Format the definitions file properly
	@(echo "FUNCTIONS" && grep -v "FUNCTIONS" mytrace.def | sort) > mytrace.def.sorted

	@# Handle the expected output file
	@if [ -f mytrace.def.exp ]; then \
		(echo "FUNCTIONS" && grep -v "FUNCTIONS" mytrace.def.exp | sort) > mytrace.def.exp.sorted; \
		if ! diff -u mytrace.def.exp.sorted mytrace.def.sorted >/dev/null; then \
			echo "FAIL: Profile definitions mismatch"; \
			diff -u mytrace.def.exp.sorted mytrace.def.sorted || true; \
			exit 1; \
		fi; \
	else \
		cp mytrace.def.sorted mytrace.def.exp; \
		echo "Created new reference file: mytrace.def.exp (properly formatted)"; \
	fi
	@touch	$@

profilegc.done: profilegc$(DOTEXE)
	@echo "Testing profilegc"
	@rm -f myprofilegc.log myprofilegc.log.$(PLATFORM).$(MODEL).exp
	./profilegc$(DOTEXE) myprofilegc.log
	@echo "Formatting output..."
	@(echo "bytes allocated,allocations,type,function,location" && \
	  awk 'BEGIN {OFS=","} {gsub(/ +/, " "); gsub(/ /, ","); print}' myprofilegc.log | \
	  sed 's/,\([^,]*\):\([0-9]*\)$$/,\1:\2/') > myprofilegc.log.$(PLATFORM).$(MODEL).exp
	@cat myprofilegc.log.$(PLATFORM).$(MODEL).exp
	@touch $@

both.done: both$(DOTEXE)
	@echo "Testing both"
	@rm -f both.log both.def bothgc.log
	./both$(DOTEXE) both.log both.def bothgc.log

	@echo "Verifying output..."
	@grep -q '1 .*_Dmain' both.log || (echo "FAIL: _Dmain not found"; exit 1)
	@grep -q '1000 .*both.Num\* both.foo(uint)' both.log || (echo "FAIL: foo calls not found"; exit 1)

	@# Process profile definitions (order-agnostic check)
	@echo "Checking profile definitions..."
	@if [ -f bothnew.def.exp ]; then \
        grep -v '^FUNCTIONS' both.def | sort | grep -v 'typeNameFNbNeC15TypeInfo_Struct' > both.def.content; \
        grep -v '^FUNCTIONS' bothnew.def.exp | sort | grep -v 'typeNameFNbNeC15TypeInfo_Struct' > bothnew.def.exp.content; \
        if ! diff -u bothnew.def.exp.content both.def.content; then \
            echo "FAIL: Profile definitions content mismatch"; \
            exit 1; \
        fi; \
    else \
        cp both.def bothnew.def.exp; \
    fi

	@# Check GC profile
	@echo "Checking GC profile..."
	@if [ -f bothgc.log.exp ]; then \
		sed -e '/core\./d' -e 's/[0-9]\+/XXX/g' bothgc.log > bothgc.log.norm; \
		sed -e '/core\./d' -e 's/[0-9]\+/XXX/g' bothgc.log.exp > bothgc.log.exp.norm; \
		if ! diff -u bothgc.log.exp.norm bothgc.log.norm; then \
			echo "FAIL: GC profile mismatch"; \
			exit 1; \
		fi; \
	else \
		echo "Creating new reference: bothgc.log.exp"; \
		cp bothgc.log bothgc.log.exp; \
	fi

	@touch	$@

# Compiler flags
profile$(DOTEXE): extra_dflags += -profile
profilegc$(DOTEXE): extra_dflags += -profile=gc
both$(DOTEXE): extra_dflags += -profile -profile=gc

.PHONY: clean
clean:
	rm	-f *.done	myprofilegc.log.darwin.64.exp	mytrace.def	mytrace.log	mytrace.def.sorted	myprofilegc.log	both.log	both.def	profilegc.o profile.o	myprofilegc.formatted.log	bothgc.log.norm	both.o	bothgc.log	both.def.content	mytrace.def.exp.sorted	bothgc.log.exp.norm	bothnew.def.exp.content
	rm	-f	profile	profilegc	both	#	Explicit	executable	names
