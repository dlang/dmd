// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/diag3672.d(100): Error: read-modify-write operations are not allowed for `shared` variables
    ++x;
      ^
fail_compilation/diag3672.d(100):        Use `core.atomic.atomicOp!"+="(x, 1)` instead
fail_compilation/diag3672.d(101): Error: read-modify-write operations are not allowed for `shared` variables
    x++;
    ^
fail_compilation/diag3672.d(101):        Use `core.atomic.atomicOp!"+="(x, 1)` instead
fail_compilation/diag3672.d(102): Error: read-modify-write operations are not allowed for `shared` variables
    --x;
      ^
fail_compilation/diag3672.d(102):        Use `core.atomic.atomicOp!"-="(x, 1)` instead
fail_compilation/diag3672.d(103): Error: read-modify-write operations are not allowed for `shared` variables
    x--;
    ^
fail_compilation/diag3672.d(103):        Use `core.atomic.atomicOp!"-="(x, 1)` instead
fail_compilation/diag3672.d(104): Error: read-modify-write operations are not allowed for `shared` variables
    x += 1;
    ^
fail_compilation/diag3672.d(104):        Use `core.atomic.atomicOp!"+="(x, 1)` instead
fail_compilation/diag3672.d(105): Error: read-modify-write operations are not allowed for `shared` variables
    x += 2;
    ^
fail_compilation/diag3672.d(105):        Use `core.atomic.atomicOp!"+="(x, 2)` instead
fail_compilation/diag3672.d(106): Error: read-modify-write operations are not allowed for `shared` variables
    x -= 3;
    ^
fail_compilation/diag3672.d(106):        Use `core.atomic.atomicOp!"-="(x, 3)` instead
fail_compilation/diag3672.d(107): Error: read-modify-write operations are not allowed for `shared` variables
    x |= y;
    ^
fail_compilation/diag3672.d(107):        Use `core.atomic.atomicOp!"|="(x, y)` instead
fail_compilation/diag3672.d(108): Error: read-modify-write operations are not allowed for `shared` variables
    x *= y;
    ^
fail_compilation/diag3672.d(108):        Use `core.atomic.atomicOp!"*="(x, y)` instead
fail_compilation/diag3672.d(109): Error: read-modify-write operations are not allowed for `shared` variables
    x /= y;
    ^
fail_compilation/diag3672.d(109):        Use `core.atomic.atomicOp!"/="(x, y)` instead
fail_compilation/diag3672.d(110): Error: read-modify-write operations are not allowed for `shared` variables
    x %= y;
    ^
fail_compilation/diag3672.d(110):        Use `core.atomic.atomicOp!"%="(x, y)` instead
fail_compilation/diag3672.d(111): Error: read-modify-write operations are not allowed for `shared` variables
    x &= y;
    ^
fail_compilation/diag3672.d(111):        Use `core.atomic.atomicOp!"&="(x, y)` instead
fail_compilation/diag3672.d(112): Error: read-modify-write operations are not allowed for `shared` variables
    x ^= y;
    ^
fail_compilation/diag3672.d(112):        Use `core.atomic.atomicOp!"^="(x, y)` instead
fail_compilation/diag3672.d(113): Error: read-modify-write operations are not allowed for `shared` variables
    x <<= y;
    ^
fail_compilation/diag3672.d(113):        Use `core.atomic.atomicOp!"<<="(x, y)` instead
fail_compilation/diag3672.d(114): Error: read-modify-write operations are not allowed for `shared` variables
    x >>= y;
    ^
fail_compilation/diag3672.d(114):        Use `core.atomic.atomicOp!">>="(x, y)` instead
fail_compilation/diag3672.d(115): Error: read-modify-write operations are not allowed for `shared` variables
    x >>>= y;
    ^
fail_compilation/diag3672.d(115):        Use `core.atomic.atomicOp!">>>="(x, y)` instead
fail_compilation/diag3672.d(116): Error: read-modify-write operations are not allowed for `shared` variables
    x ^^= y;
    ^
fail_compilation/diag3672.d(116):        Use `core.atomic.atomicOp!"^^="(x, y)` instead
fail_compilation/diag3672.d(117): Error: read-modify-write operations are not allowed for `shared` variables
    ++ptr;
      ^
fail_compilation/diag3672.d(117):        Use `core.atomic.atomicOp!"+="(ptr, 1)` instead
fail_compilation/diag3672.d(118): Error: read-modify-write operations are not allowed for `shared` variables
    ptr++;
    ^
fail_compilation/diag3672.d(118):        Use `core.atomic.atomicOp!"+="(ptr, 1)` instead
fail_compilation/diag3672.d(119): Error: read-modify-write operations are not allowed for `shared` variables
    --ptr;
      ^
fail_compilation/diag3672.d(119):        Use `core.atomic.atomicOp!"-="(ptr, 1)` instead
fail_compilation/diag3672.d(120): Error: read-modify-write operations are not allowed for `shared` variables
    ptr--;
    ^
fail_compilation/diag3672.d(120):        Use `core.atomic.atomicOp!"-="(ptr, 1)` instead
---
*/

// Line 1 starts here
shared int x;
shared int y;
shared int* ptr;
shared static this() { ptr = new int; } // silence null-dereference errors

void main()
{
    ++x;
    x++;
    --x;
    x--;
    x += 1;
    x += 2;
    x -= 3;
    x |= y;
    x *= y;
    x /= y;
    x %= y;
    x &= y;
    x ^= y;
    x <<= y;
    x >>= y;
    x >>>= y;
    x ^^= y;
    ++ptr;
    ptr++;
    --ptr;
    ptr--;
}
