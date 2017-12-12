/*
TEST_OUTPUT:
---
fail_compilation/bug9631.d(17): Error: cannot implicitly convert expression `F()` of type `bug9631.tem!().F` to `bug9631.F`
---
*/

struct F { }

template tem()
{
    struct F { }
}

void convert()
{
    F x = tem!().F();
}

/*
TEST_OUTPUT:
---
fail_compilation/bug9631.d(31): Error: incompatible types for ((x) == (y)): 'bug9631.F' and 'bug9631.tem!().F'
---
*/

void equal()
{
    F x;
    auto y = tem!().F();
    bool b = x == y;
}
