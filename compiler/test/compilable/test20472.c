// https://github.com/dlang/dmd/issues/20472
typedef struct {
    char c;
} stuff;

char test20472(void)
{
    stuff s[1];
    s->c = 1;
    return s->c;
}
_Static_assert(test20472() == 1, "1");
