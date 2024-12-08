/*
TEST_OUTPUT:
---
fail_compilation/diag3438.d(26): Error: constructor `diag3438.F1.this` all parameters have default arguments, but structs cannot have default constructors.
struct F1 { this(int x = 1) { } }
            ^
fail_compilation/diag3438.d(27): Error: constructor `diag3438.F2.this` all parameters have default arguments, but structs cannot have default constructors.
struct F2 { this(int x = 1, ...) { } }
            ^
fail_compilation/diag3438.d(30): Error: constructor `diag3438.F5.this` is marked `@disable`, so it cannot have default arguments for all parameters.
struct F5 { @disable this(int x = 1); }
                     ^
fail_compilation/diag3438.d(30):        Use `@disable this();` if you want to disable default initialization.
fail_compilation/diag3438.d(31): Error: constructor `diag3438.F6.this` is marked `@disable`, so it cannot have default arguments for all parameters.
struct F6 { @disable this(int x = 1) { } }
                     ^
fail_compilation/diag3438.d(31):        Use `@disable this();` if you want to disable default initialization.
fail_compilation/diag3438.d(32): Error: constructor `diag3438.F7.this` all parameters have default arguments, but structs cannot have default constructors.
struct F7 { this(int x = 1, int y = 2) { } }
            ^
---
*/

import core.vararg;

struct F1 { this(int x = 1) { } }
struct F2 { this(int x = 1, ...) { } }
struct F3 { this(...) { } } // ok
struct F4 { this(int[] x...) { } }  // ok
struct F5 { @disable this(int x = 1); }
struct F6 { @disable this(int x = 1) { } }
struct F7 { this(int x = 1, int y = 2) { } }
