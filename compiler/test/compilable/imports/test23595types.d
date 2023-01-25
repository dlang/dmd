module imports.test23595types;

enum __WORDSIZE = 64;

static if (__WORDSIZE)
    enum __SIZEOF_PTHREAD_MUTEX_T = 1;

union pthread_mutex_t
{
    byte[__SIZEOF_PTHREAD_MUTEX_T] __size;
}
