/* REQUIRED_ARGS: -main
 * TEST_OUTPUT:
---
fail_compilation/b11006.d(10): Error: Operands must point to the same type (got void and int)
fail_compilation/b11006.d(10):        while evaluating: `static assert(cast(void*)8 - cast(int*)0 == 2)`
fail_compilation/b11006.d(11): Error: Operands must point to the same type (got int and void)
fail_compilation/b11006.d(11):        while evaluating: `static assert(cast(int*)8 - cast(void*)0 == 8)`
---
 */
static assert(cast(void*)8 - cast(int*) 0 == 2);
static assert(cast(int*) 8 - cast(void*)0 == 8);
