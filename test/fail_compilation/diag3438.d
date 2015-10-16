// REQUIRED_ARGS: -w
/*
TEST_OUTPUT:
---
fail_compilation/diag3438.d(15): Warning: constructor diag3438.F1.this default constructor for structs only allowed with @disable, no body, and no parameters
fail_compilation/diag3438.d(16): Warning: constructor diag3438.F2.this default constructor for structs only allowed with @disable, no body, and no parameters
fail_compilation/diag3438.d(17): Warning: constructor diag3438.F3.this default constructor for structs only allowed with @disable, no body, and no parameters
fail_compilation/diag3438.d(19): Warning: constructor diag3438.F5.this default constructor for structs only allowed with @disable, no body, and no parameters
fail_compilation/diag3438.d(20): Warning: constructor diag3438.F6.this default constructor for structs only allowed with @disable, no body, and no parameters
---
*/

import core.vararg;

struct F1 { this(int x = 1) { } }
struct F2 { this(int x = 1, ...) { } }
struct F3 { this(...) { } }
struct F4 { this(int[] x...) { } }  // ok
struct F5 { @disable this(int x = 1); }
struct F6 { @disable this(int x = 1) { } }
