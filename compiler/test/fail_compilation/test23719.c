/* TEST_OUTPUT:
---
fail_compilation/test23719.c(15): Error: since `abc` is a pointer, use `abc->b` instead of `abc.b`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23719

struct S { int a, b; };

struct S *abc = &(struct S){ 1, 2 };

int main()
{
    int j = abc.b;
    if (j != 2)
        return 1;
    return 0;
}
