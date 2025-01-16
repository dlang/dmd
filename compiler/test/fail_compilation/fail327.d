/*
TEST_OUTPUT:
---
fail_compilation/fail327.d(11): Error: executing an `asm` statement without `@trusted` annotation is not allowed in a `@safe` function
fail_compilation/fail327.d(12): Deprecation: `asm` statement cannot be marked `@safe`, use `@system` or `@trusted` instead
---
*/

@safe void* foo()
{
    asm { xor EAX,EAX; }
    asm @safe
    {
        mov [RIP], 0;
    }
    void* p;
RIP:
    return p;
}
