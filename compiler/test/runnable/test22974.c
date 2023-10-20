// EXTRA_SOURCES: imports/test22974b.c

/* https://issues.dlang.org/show_bug.cgi?id=22974
 */

int main()
{
    extern int ccc();
    extern int xxx;
    xxx = ccc();
    return xxx - 1;
}
