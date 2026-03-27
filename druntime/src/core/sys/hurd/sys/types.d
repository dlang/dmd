module core.sys.hurd.sys.types;

version (Hurd):
extern(C):
@nogc:
nothrow:


enum __pthread_process_shared
{
    __PTHREAD_PROCESS_PRIVATE = 0,
    __PTHREAD_PROCESS_SHARED,
}

enum __pthread_inheritsched
{
    __PTHREAD_EXPLICIT_SCHED = 0,
    __PTHREAD_INHERIT_SCHED,
}

enum __pthread_contentionscope
{
    __PTHREAD_SCOPE_SYSTEM = 0,
    __PTHREAD_SCOPE_PROCESS,
}

enum __pthread_detachstate
{
    __PTHREAD_CREATE_JOINABLE = 0,
    __PTHREAD_CREATE_DETACHED,
}

enum __pthread_mutex_type
{
    __PTHREAD_MUTEX_TIMED,
    __PTHREAD_MUTEX_ERRORCHECK,
    __PTHREAD_MUTEX_RECURSIVE,
}

enum __pthread_mutex_protocol
{
    __PTHREAD_PRIO_NONE = 0,
    __PTHREAD_PRIO_INHERIT,
    __PTHREAD_PRIO_PROTECT
}

struct __sched_param
{
    int __sched_priority;
}



// ????
struct __pthread
{
    ubyte[1] _address;
}
