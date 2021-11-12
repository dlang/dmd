/*
REQUIRED_ARGS: -betterC
PERMUTE_ARGS: -m32
RUN_OUTPUT:
---
C: 1, 2, 3
D: 1, 2, 3
---
*/

extern(C) void printf (scope const(char*) format, ...) nothrow @nogc;

template callFunc(string L)
{
    enum callFunc = q{
            version(Posix) // System V ABI
            {
                size_t x, y, z;
                version(X86_64)
                {
                    asm pure @nogc nothrow
                    {
                        mov x, RDI;
                        mov y, RSI;
                        mov z, RDX;
                    }
                } else {
                    asm pure @nogc nothrow
                    {
                        mov EAX, [EBP+8]; mov x, EAX;
                        mov EAX, [EBP+12]; mov y, EAX;
                        mov EAX, [EBP+16]; mov z, EAX;
                    }
                }
            } else // Unknown
                immutable size_t x = 1, y = 2, z = 3;
        } ~ `printf("` ~ L ~ `: %zu, %zu, %zu\n", x,y,z);`;
}

extern (C) void ccall(size_t , size_t , size_t ) nothrow @nogc @system
{
    mixin(callFunc!"C");
}

extern (D) void dcall(size_t , size_t , size_t ) nothrow @nogc @system
{
    mixin(callFunc!"D");
}

extern (C) int main()
{
    size_t a = 0x1;
    size_t b = 0x2;
    size_t c = 0x3;

    ccall(a, b, c);
    dcall(a, b, c);

    return 0;
}

