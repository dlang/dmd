// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/fail9613.d(16): Error: `(arguments)` expected following `const(byte)`, not `.`
    auto x = const byte.init;
                       ^
fail_compilation/fail9613.d(16): Error: semicolon expected following auto declaration, not `.`
    auto x = const byte.init;
                       ^
---
*/

void main()
{
    auto x = const byte.init;
}
