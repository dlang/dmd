// https://github.com/dlang/dmd/pull/21740
int strcmp(const char *, const char *);

void  \u00e9 (void)
{
    __check(strcmp (__func__, "\u00e9") == 0);
}

int main (void)
{
    \u00e9 ();
    return 0;
}
