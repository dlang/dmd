/* https://issues.dlang.org/show_bug.cgi?id=23038
 */

char a;
struct S
{
    long long a;
    char b[sizeof(a)];
    //typeof(a) c;
} s;
_Static_assert(sizeof(s.b) == sizeof(char), "1");
//_Static_assert(sizeof(s.c) == sizeof(char), "2");

long long test(struct S t)
{
    return t.a;
}
