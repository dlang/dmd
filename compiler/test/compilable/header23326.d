/*
REQUIRED_ARGS: -o- -Hf${RESULTS_DIR}/compilable/header23326.di
OUTPUT_FILES: ${RESULTS_DIR}/compilable/header23326.di

TEST_OUTPUT:
---
=== ${RESULTS_DIR}/compilable/header23326.di
// D import file generated from 'compilable/header23326.d'
enum i = ((x) => x * 2)(3);
enum j = ((x) => x * 2)(4);
extern typeof(((x) => x * 2)(5)) d;
---
*/

// https://github.com/dlang/dmd/issues/23326
enum i = (x => x * 2)(3);
enum j = ((x) => x * 2)(4);
auto d = (x => x * 2)(5);
