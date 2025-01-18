import etc.linux.memoryerror;

int* x = null;

int main()
{
    registerMemoryAssertHandler;
    return *x;
}
