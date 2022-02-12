
// https://issues.dlang.org/show_bug.cgi?id=22761

extern long reg22344 (long adler, const char *buf, int len);

long reg22344(adler, buf, len)
    long adler;
    const char *buf;
    int len;
{
    return 0;
}
