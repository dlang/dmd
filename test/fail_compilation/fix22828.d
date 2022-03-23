/*
REQUIRED_ARGS: -m32
TEST_OUTPUT:
---
fail_compilation/fix22828.d(104): Error: cannot implicitly convert expression `len` of type `ulong` to `uint`
fail_compilation/fix22828.d(105): Error: cannot implicitly convert expression `len` of type `ulong` to `uint`
fail_compilation/fix22828.d(106): Error: cannot implicitly convert expression `len` of type `ulong` to `uint`
---
 */

#line 100

int main() {
    int i;
    ulong len;
    *(&i + len) = 0;
    *(len + &i) = 0;
    (&i)[len] = 0;

    return 0;
}
