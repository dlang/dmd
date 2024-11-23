/* TEST_OUTPUT:
---
fail_compilation/test20610.d(22): Error: cannot modify `const` expression `field`
        field = 10;
        ^
---
 */

// https://issues.dlang.org/show_bug.cgi?id=20610

struct S
{
    int what;
}

void main()
{
    S record;

    foreach (const ref field; record.tupleof)
    {
        field = 10;
    }
}
