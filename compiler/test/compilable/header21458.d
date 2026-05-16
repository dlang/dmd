/*
REQUIRED_ARGS: -o- -Hf${RESULTS_DIR}/compilable/header21458.di
OUTPUT_FILES: ${RESULTS_DIR}/compilable/header21458.di

TEST_OUTPUT:
---
=== ${RESULTS_DIR}/compilable/header21458.di
// D import file generated from 'compilable/header21458.d'
static foreach (x; 0 .. 1)
{
	static assert(true);
	static assert(true);
}
static foreach (y; 0 .. 1)
{
	static assert(true);
}
static foreach (z; 0 .. 1)
{
}
---
*/

// https://github.com/dlang/dmd/issues/21458
static foreach (x; 0..1)
{
    static assert(true);
    static assert(true);
}

static foreach (y; 0..1)
{
    static assert(true);
}

static foreach (z; 0..1)
{
}
