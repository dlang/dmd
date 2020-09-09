// REQUIRED_ARGS: -de
// PERMUTE_ARGS:
// EXTRA_FILES: imports/a15856.d
/*
TEST_OUTPUT:
---
---
*/

class Foo
{
    import imports.a15856;

    struct Bar
    {
        c_long a;
    }
}
