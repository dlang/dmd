
// test __builtin_va_start and __builtin_va_end

typedef __builtin_va_list __gnuc_va_list;
typedef __gnuc_va_list va_list;

int gzvprintf(const char *format, va_list va);

int gzprintf(const char *format, ...)
{
    va_list va;
    int ret;

    __builtin_va_start(va,format);
    ret = gzvprintf(format, va);
    __builtin_va_end(va);
    return ret;
}
