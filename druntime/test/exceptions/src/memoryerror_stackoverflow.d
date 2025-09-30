import etc.linux.memoryerror;
import core.volatile;

pragma(inline, false):

void f(ref ubyte[1024] buf)
{
    ubyte[1024] cpy = buf;
    volatileStore(&cpy[0], 1);
    g(cpy);
}

void g(ref ubyte[1024] buf)
{
    ubyte[1024] cpy = buf;
    volatileStore(&cpy[0], 2);
    f(cpy);
}

void main()
{
    registerMemoryAssertHandler;
    ubyte[1024] buf;
    f(buf);
}
