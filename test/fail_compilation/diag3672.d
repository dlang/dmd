// PERMUTE_ARGS:
// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/diag3672.d(36): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"+="(x, 1) instead.
fail_compilation/diag3672.d(37): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"+="(x, 1) instead.
fail_compilation/diag3672.d(38): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"-="(x, 1) instead.
fail_compilation/diag3672.d(39): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"-="(x, 1) instead.
fail_compilation/diag3672.d(40): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"+="(x, 1) instead.
fail_compilation/diag3672.d(41): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"+="(x, 2) instead.
fail_compilation/diag3672.d(42): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"-="(x, 3) instead.
fail_compilation/diag3672.d(43): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"|="(x, y) instead.
fail_compilation/diag3672.d(44): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"*="(x, y) instead.
fail_compilation/diag3672.d(45): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"/="(x, y) instead.
fail_compilation/diag3672.d(46): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"%="(x, y) instead.
fail_compilation/diag3672.d(47): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"&="(x, y) instead.
fail_compilation/diag3672.d(48): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"^="(x, y) instead.
fail_compilation/diag3672.d(49): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"<<="(x, y) instead.
fail_compilation/diag3672.d(50): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!">>="(x, y) instead.
fail_compilation/diag3672.d(51): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!">>>="(x, y) instead.
fail_compilation/diag3672.d(52): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"^^="(x, y) instead.
fail_compilation/diag3672.d(53): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"+="(ptr, 1) instead.
fail_compilation/diag3672.d(54): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"+="(ptr, 1) instead.
fail_compilation/diag3672.d(55): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"-="(ptr, 1) instead.
fail_compilation/diag3672.d(56): Deprecation: Read-modify-write operations are not allowed for shared variables. Use core.atomic.atomicOp!"-="(ptr, 1) instead.
---
*/
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
