// https://issues.dlang.org/show_bug.cgi?id=23935

typedef struct
        __declspec(align(16))
        __pragma(warning(push))
        __pragma(warning(disable:4845))
        __declspec(no_init_all)
        __pragma(warning(pop))
        _CONTEXT
{
    int i;
} _CONTEXT;
