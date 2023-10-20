
// https://issues.dlang.org/show_bug.cgi?id=22761

extern long reg22344 (long adler, const char *buf, int len);

long reg22344(adler, buf, len)
    long adler;
    const char *buf;
    int len;
{
    return 0;
}

// https://issues.dlang.org/show_bug.cgi?id=22896

void fn(int);
void fn(const int x);
