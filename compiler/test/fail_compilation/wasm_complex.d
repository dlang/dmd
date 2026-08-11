/*
REQUIRED_ARGS: -mwasm32 -os=wasm
TEST_OUTPUT:
---
fail_compilation/wasm_complex.d(111): Deprecation: use of complex type `cdouble` is deprecated, use `std.complex.Complex!(double)` instead
fail_compilation/wasm_complex.d(103): Deprecation: use of complex type `cdouble` is deprecated, use `std.complex.Complex!(double)` instead
fail_compilation/wasm_complex.d(104): Deprecation: use of complex type `cfloat` is deprecated, use `std.complex.Complex!(float)` instead
fail_compilation/wasm_complex.d(105): Deprecation: use of complex type `creal` is deprecated, use `std.complex.Complex!(real)` instead
Deprecation: use of complex type `const(cdouble)` is deprecated, use `std.complex.Complex!(double)` instead
fail_compilation/wasm_complex.d(103): Error: complex type `cdouble` is not supported for the WebAssembly target
fail_compilation/wasm_complex.d(104): Error: complex type `cfloat` is not supported for the WebAssembly target
fail_compilation/wasm_complex.d(105): Error: complex type `creal` is not supported for the WebAssembly target
fail_compilation/wasm_complex.d(111): Error: complex type `cdouble` is not supported for the WebAssembly target
---
*/

#line 100

void f()
{
    cdouble a;
    cfloat b;
    creal c;
}

static assert(!is(int : creal));
static assert(is(cfloat == cfloat));

struct S { cdouble field; }
