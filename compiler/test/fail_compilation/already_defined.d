/**
TEST_OUTPUT:
---
fail_compilation/already_defined.d(53): Error: declaration `already_defined.func1.a` is already defined
    bool a;
    ^
fail_compilation/already_defined.d(52):        `variable` `a` is defined here
    int a;
        ^
fail_compilation/already_defined.d(59): Error: declaration `already_defined.func2.core` is already defined
    string core;
    ^
fail_compilation/already_defined.d(58):        `import` `core` is defined here
    import core.stdc.stdio;
           ^
fail_compilation/already_defined.d(77): Error: declaration `Ident(T)` is already defined
    template Ident (T) { alias Ident = T; }
    ^
fail_compilation/already_defined.d(76):        `template` `Ident(T)` is defined here
    template Ident (T) { alias Ident = T; }
    ^
fail_compilation/already_defined.d(85): Error: declaration `Tstring` is already defined
    alias Tstring = Ident!string;
    ^
fail_compilation/already_defined.d(84):        `alias` `Tstring` is defined here
    alias Tstring = Ident!string;
    ^
fail_compilation/already_defined.d(91): Error: declaration `T` is already defined
    static if (is(int T == int)) {}
               ^
fail_compilation/already_defined.d(90):        `alias` `T` is defined here
    static if (is(int T == int)) {}
               ^
fail_compilation/already_defined.d(97): Error: declaration `core` is already defined
    static if (is(int core == int)) {}
               ^
fail_compilation/already_defined.d(96):        `import` `core` is defined here
    import core.stdc.stdio;
           ^
fail_compilation/already_defined.d(103): Error: declaration `core` is already defined
    static if (is(string : core[], core)) {}
               ^
fail_compilation/already_defined.d(102):        `import` `core` is defined here
    import core.stdc.stdio;
           ^
---
*/

// Line 1 starts here
void func1 ()
{
    int a;
    bool a;
}

void func2 ()
{
    import core.stdc.stdio;
    string core;
}

void func3 ()
{
    {
        import core.stdc.stdio;
    }

    {
        // No conflict
        string core;
    }
}

void func4 ()
{
    template Ident (T) { alias Ident = T; }
    template Ident (T) { alias Ident = T; }
}

void func5 ()
{
    template Ident (T) { alias Ident = T; }

    alias Tstring = Ident!string;
    alias Tstring = Ident!string;
}

void func6 ()
{
    static if (is(int T == int)) {}
    static if (is(int T == int)) {}
}

void func7 ()
{
    import core.stdc.stdio;
    static if (is(int core == int)) {}
}

void func8 ()
{
    import core.stdc.stdio;
    static if (is(string : core[], core)) {}
}
