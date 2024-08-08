import etc.linux.memoryerror;

int* x = null;

void f(ubyte[] arr)
{
    ubyte[1024] buf = 0;
    f(buf[]);
}

void main()
{
    registerMemoryAssertHandler();
    f([]);
}
