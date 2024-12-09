/**
TEST_OUTPUT:
---
fail_compilation/ice23781.d(12): Error: variable `b` cannot be read at compile time
enum E2 = &E1.func1();
                   ^
---
**/
struct Bar { int i; }
ref const(Bar) func1 (const return ref Bar b) { return b; }
immutable E1 = Bar();
enum E2 = &E1.func1();
