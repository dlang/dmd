/*
TEST_OUTPUT:
---
fail_compilation/ice13221.d(22): Error: variable `r` cannot be read at compile time
        enum i = r;
                 ^
---
*/

struct Tuple(T...)
{
    T field;
    alias field this;
}

template test(T) {}

void main()
{
    foreach (r; 0 .. 0)
    {
        enum i = r;
        test!(Tuple!bool[i]);
    }
}
