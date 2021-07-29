/*
REQUIRED_ARGS: -o- -Hf${RESULTS_DIR}/compilable/hdrgen_dip1029.di
PERMUTE_ARGS:
OUTPUT_FILES: ${RESULTS_DIR}/compilable/hdrgen_dip1029.di

TEST_OUTPUT:
---
=== ${RESULTS_DIR}/compilable/hdrgen_dip1029.di
// D import file generated from 'compilable/hdrgen_dip1029.d'
module foo.bar.foobar.baz;
void foo();
throw void foobar();
nothrow void bar();
nothrow
{
	throw void n_t();
	void n();
}
void _t();
throw void t();
struct S
{
	throw void foo();
}
class C
{
	throw void foo();
}
throw
{
	void t2();
	nothrow void n2();
}
---
*/
module foo.bar.foobar.baz;

void foo() {}

void foobar() throw {}
void bar() nothrow {}

nothrow {
    void n_t() throw;
    void n();
}

void _t();
void t() throw;

struct S {
    void foo() throw;
}

class C {
    void foo() throw;
}

throw:
    void t2();
    void n2() nothrow;
