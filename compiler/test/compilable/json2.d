/*
PERMUTE_ARGS:
REQUIRED_ARGS: -d -o- -Xf=${RESULTS_DIR}/compilable/json2.out -Xi=compilerInfo -Xi=buildInfo -Xi=modules -Xi=semantics
OUTPUT_FILES: ${RESULTS_DIR}/compilable/json2.out
TRANSFORM_OUTPUT: sanitize_json
TEST_OUTPUT_FILE: extra-files/json2.json
*/

import json;
