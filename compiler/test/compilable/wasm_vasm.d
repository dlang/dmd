/*
DISABLED: linux osx win freebsd dragonflybsd netbsd openbsd
REQUIRED_ARGS: -vasm -betterC
TEST_OUTPUT:
---
(func $_D9wasm_vasm8fortyTwoFZi (result i32)
0000:  i32.const 42
0002:  return
)
---
*/

int fortyTwo()
{
    return 42;
}
