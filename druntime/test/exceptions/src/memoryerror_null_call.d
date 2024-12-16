import etc.linux.memoryerror;

void function() foo = null;

void main()
{
    registerMemoryAssertHandler;
    foo();
}
