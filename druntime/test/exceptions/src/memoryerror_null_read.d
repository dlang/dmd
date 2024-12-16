import etc.linux.memoryerror;

int* x = null;

void main()
{
    registerMemoryAssertHandler;
    *x = 3;
}
