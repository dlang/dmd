/*
TEST_OUTPUT:
---
fail_compilation/diag6677.d(1): Error: static constructors cannot be 'const'
fail_compilation/diag6677.d(2): Error: static constructors cannot be 'inout'
fail_compilation/diag6677.d(3): Error: static constructors cannot be 'immutable'
fail_compilation/diag6677.d(4): Error: to create a shared static constructor, move 'shared' in front of 'static'
fail_compilation/diag6677.d(5): Error: to create a shared static constructor, move 'shared' in front of 'static'
fail_compilation/diag6677.d(5): Error: static constructors cannot be 'const'
fail_compilation/diag6677.d(7): Error: shared static constructors cannot be 'const'
fail_compilation/diag6677.d(8): Error: shared static constructors cannot be 'inout'
fail_compilation/diag6677.d(9): Error: shared static constructors cannot be 'immutable'
fail_compilation/diag6677.d(10): Error: shared static constructors cannot be 'shared'
fail_compilation/diag6677.d(11): Error: shared static constructors cannot be 'shared const'
---
*/

#line 1
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
