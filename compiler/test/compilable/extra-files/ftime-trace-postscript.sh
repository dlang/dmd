#!/usr/bin/env bash

# Just test that the output file exists
[[ -f ${OUTPUT_BASE}.json ]] || { echo "ERROR: ${OUTPUT_BASE}.json does not exist"; exit 1; }

# The output itself is not deterministic but a future test could verify that it satisfies a JSON schema
