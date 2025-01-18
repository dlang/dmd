import etc.linux.memoryerror;

pragma(inline, false):

void f(ref ubyte[1024] buf)
{
    ubyte[1024] cpy = buf;
    g(cpy);
}

void g(ref ubyte[1024] buf)
{
    ubyte[1024] cpy = buf;
    f(cpy);
}

void main()
{
    registerMemoryAssertHandler;
    ubyte[1024] buf;
    f(buf);
}
