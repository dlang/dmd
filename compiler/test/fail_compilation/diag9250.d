// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/diag9250.d(23): Error: cannot implicitly convert expression `10u` of type `uint` to `Foo`
    Foo x = bar.length;  // error here
            ^
fail_compilation/diag9250.d(26): Error: cannot implicitly convert expression `10u` of type `uint` to `void*`
              bar.length :  // error here
              ^
---
*/

struct Foo
{
    ubyte u;
}

void main()
{
    uint[10] bar;

    Foo x = bar.length;  // error here

    void* y = bar.length ?
              bar.length :  // error here
              bar.length;
}
