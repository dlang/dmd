// REQUIRED_ARGS: -o- -fPIC
/*
TEST_OUTPUT:
---
fail_compilation/fail13939.d(14): Error: cannot directly load global variable 'val' with PIC code
---
*/
version(Windows) static assert(0);
void test1()
{
    __gshared int val;
    asm
    {
        mov EAX, val;
    }
}
