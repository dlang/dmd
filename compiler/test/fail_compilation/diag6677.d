/*
TEST_OUTPUT:
---
fail_compilation/diag6677.d(37): Error: static constructor cannot be `const`
static this() const { }
^
fail_compilation/diag6677.d(38): Error: static constructor cannot be `inout`
static this() inout { }
^
fail_compilation/diag6677.d(39): Error: static constructor cannot be `immutable`
static this() immutable { }
^
fail_compilation/diag6677.d(40): Error: use `shared static this()` to declare a shared static constructor
static this() shared { }
^
fail_compilation/diag6677.d(41): Error: use `shared static this()` to declare a shared static constructor
static this() const shared { }
^
fail_compilation/diag6677.d(43): Error: shared static constructor cannot be `const`
shared static this() const { }
^
fail_compilation/diag6677.d(44): Error: shared static constructor cannot be `inout`
shared static this() inout { }
^
fail_compilation/diag6677.d(45): Error: shared static constructor cannot be `immutable`
shared static this() immutable { }
^
fail_compilation/diag6677.d(46): Error: redundant attribute `shared`
shared static this() shared { }
                            ^
fail_compilation/diag6677.d(47): Error: redundant attribute `shared`
shared static this() const shared { }
                                  ^
---
*/

static this() const { }
static this() inout { }
static this() immutable { }
static this() shared { }
static this() const shared { }

shared static this() const { }
shared static this() inout { }
shared static this() immutable { }
shared static this() shared { }
shared static this() const shared { }
