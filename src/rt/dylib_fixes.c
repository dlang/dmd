
// OS X support for dynamic libraries

void* _Dmain __attribute__((weak));

char rt_init ();
char rt_term ();

__attribute__((constructor)) static void initializer ()
{
    rt_init();
}

__attribute__((destructor)) static void finalizer ()
{
    rt_term();
}

