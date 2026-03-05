/*TEST_OUTPUT:
---
1
s
---
*/
struct Tuple(S...)
{
    S fields;
    alias fields this;
}

void f()
{
    enum t = Tuple!(int, string)(1, "s");

    static foreach (a; t)
        pragma(msg, a);
}
