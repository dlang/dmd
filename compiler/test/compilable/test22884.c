// https://issues.dlang.org/show_bug.cgi?id=22884

int printf(const char*, ...);
typedef void (*funcptr)(void);

funcptr a = printf;
funcptr b = (void(*)())printf;
funcptr c = (funcptr)printf;
funcptr d = &printf;

funcptr foo(void)
{
    funcptr f = (funcptr)printf;
    return f;
}
