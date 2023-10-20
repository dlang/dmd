// https://issues.dlang.org/show_bug.cgi?id=22894


struct S
{
    struct S *s;
    int *first;
    int **last;
};
struct S my_S =
{
    &my_S,
    0,
    &my_S.first
};
