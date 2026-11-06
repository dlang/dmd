/* TEST_OUTPUT:
---
fail_compilation/fix24089.c(11): Error: cannot take address of imported symbol `foo` at compile time
---
 */

// https://github.com/dlang/dmd/issues/24089

__declspec(dllimport) int __stdcall foo(void);
struct S { int (*fp)(void); };
struct S s = { &foo };
int main(void) { return 0; }
