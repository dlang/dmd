// https://github.com/dlang/dmd/issues/22453
// -preview=safer should ignore C files
// REQUIRED_ARGS: -preview=safer
int f(int *p)
{
    return p[1];
}
