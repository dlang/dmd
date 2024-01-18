/* REQUIRED_ARGS: runnable/extra-files/test24129b.c
 */

// https:issues.dlang.org/show_bug_cgi?id=24129

inline int dup()
{
    return 73;
}

void *def()
{
    return &dup;
}

int main()
{
    return 0;
}
