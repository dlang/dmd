/*
REQUIRED_ARGS: -o- -Hf${RESULTS_DIR}/compilable/header18479.di -Icompilable/extra-files
PERMUTE_ARGS:
OUTPUT_FILES: ${RESULTS_DIR}/compilable/header18479.di

TEST_OUTPUT:
---
=== ${RESULTS_DIR}/compilable/header18479.di
// D import file generated from 'compilable/header18479.d'
module header18479;
import a.object;
public import a.object;
---
*/

// https://github.com/dlang/dmd/issues/18479
// import of module named `object` with package qualifier must not be dropped from header
module header18479;
import a.object;
public import a.object;
