/*
TEST_OUTPUT:
---
fail_compilation/fail11532.d(25): Error: cannot pass static arrays to `extern(C)` vararg functions
    cvararg(0, arr);
               ^
fail_compilation/fail11532.d(26): Error: cannot pass dynamic arrays to `extern(C)` vararg functions
    cvararg(0, arr[]);
                  ^
fail_compilation/fail11532.d(27): Error: cannot pass static arrays to `extern(C++)` vararg functions
    cppvararg(0, arr);
                 ^
fail_compilation/fail11532.d(28): Error: cannot pass dynamic arrays to `extern(C++)` vararg functions
    cppvararg(0, arr[]);
                    ^
---
*/

extern(C) void cvararg(int, ...);
extern(C++) void cppvararg(int, ...);

void main()
{
    int[2] arr = [0x99999999, 0x88888888];
    cvararg(0, arr);
    cvararg(0, arr[]);
    cppvararg(0, arr);
    cppvararg(0, arr[]);
}
