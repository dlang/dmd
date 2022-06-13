// https://issues.dlang.org/show_bug.cgi?id=22597

typedef __builtin_va_list va_list;
int vsprintf(char *s, const char *format, va_list va);
int printf(const char *s, ...);

int test22597(const char *format, ...)
{
    va_list va;
    __builtin_va_start(va,format);
    va_list va2;
    __builtin_va_copy(va2, va);
    const char *s = __builtin_va_arg(va, const char *);
    if (*s != 'h')
    {
        printf("test22597 failed `%c`\n", *s);
        return 1;
    }
    char buf[32];
    int ret = vsprintf(buf, format, va2);
    __builtin_va_end(va);
    __builtin_va_end(va2);
    return ret;
}

int main()
{
    if (test22597(", %s!", "hello") != 8)
    {
        printf("test22597 failed\n");
        return 1;
    }
    return 0;
}
