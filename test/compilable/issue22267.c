//https://issues.dlang.org/show_bug.cgi?id=22267
typedef signed int int32_t;
void exit(int);
int printf(const char *fmt, ...);
int32_t ret()
{
    int32_t init = (1 + 3);
    return init;
}
_Static_assert(ret() == 4, "Ret != 4");