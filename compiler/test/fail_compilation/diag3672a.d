// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/diag3672a.d(29): Error: read-modify-write operations are not allowed for `shared` variables
    ns.x++;
    ^
fail_compilation/diag3672a.d(29):        Use `core.atomic.atomicOp!"+="(ns.x, 1)` instead
fail_compilation/diag3672a.d(31): Error: read-modify-write operations are not allowed for `shared` variables
    s.sx++;
    ^
fail_compilation/diag3672a.d(31):        Use `core.atomic.atomicOp!"+="(s.sx, 1)` instead
fail_compilation/diag3672a.d(38): Error: read-modify-write operations are not allowed for `shared` variables
    s.var++;
    ^
fail_compilation/diag3672a.d(38):        Use `core.atomic.atomicOp!"+="(s.var, 1)` instead
fail_compilation/diag3672a.d(39): Error: read-modify-write operations are not allowed for `shared` variables
    s.var -= 2;
    ^
fail_compilation/diag3672a.d(39):        Use `core.atomic.atomicOp!"-="(s.var, 2)` instead
---
*/
class NS { shared int x; }
shared class S { int sx; }

void main()
{
    NS ns = new NS;
    ns.x++;
    S s = new S;
    s.sx++;
}

void test13003()
{
    struct S { int var; }
    shared S s;
    s.var++;
    s.var -= 2;
}
