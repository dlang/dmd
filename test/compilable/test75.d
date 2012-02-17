module test75;

import imports.test75;

// templates should have full access to their arguments
void bar()
{
    version (none) // doesn't work yet for functions
        foo!baz();
}

private void baz()
{
}

void tbar()
{
    tfoo!tbaz();
}

private template tbaz()
{
    enum tbaz = 5;
}

void Tbar()
{
    Tfoo!Tbaz();
}

private struct Tbaz
{
}
