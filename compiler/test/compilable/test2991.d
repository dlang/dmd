// EXTRA_FILES: imports/test2991.d
module test2991;

void foo()
{
}

class C
{
    import imports.test2991;

    void bar() { foo(); }
}
