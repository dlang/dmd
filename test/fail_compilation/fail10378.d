// REQUIRED_ARGS: -o- -debug

/*
TEST_OUTPUT:
---
fail_compilation/fail10378.d(18): Error: imported symbol 'imports.m10378a.text(A...)(A args)' is shadowing local symbol 'fail10378.test10378a.text'
fail_compilation/fail10378.d(21): Error: imported symbol 'imports.m10378a.foo' is shadowing local symbol 'fail10378.test10378a.foo'
fail_compilation/fail10378.d(25): Error: imported symbol 'imports.m10378a.text(A...)(A args)' is shadowing local symbol 'fail10378.test10378a.text'
fail_compilation/fail10378.d(28): Error: imported symbol 'imports.m10378a.foo' is shadowing local symbol 'fail10378.test10378a.foo'
fail_compilation/fail10378.d(32): Error: imported symbol 'imports.m10378a.text(A...)(A args)' is shadowing local symbol 'fail10378.test10378a.text'
fail_compilation/fail10378.d(35): Error: imported symbol 'imports.m10378a.foo' is shadowing local symbol 'fail10378.test10378a.foo'
---
*/
void test10378a(string text)
{
    {
        import imports.m10378a;
        auto foo = text;    // imported symbol shadowing local one
        foo = "abc";        // no error, local variable 'foo' is preferred
        import imports.m10378a;
        auto bar = foo;     // imported symbol shadowing local one
    }
    {
        debug import imports.m10378a;
        auto foo = text;
        foo = "abc";
        debug import imports.m10378a;
        auto bar = foo;
    }
    {
        L1: import imports.m10378a;
        auto foo = text;
        foo = "abc";
        L2: import imports.m10378a;
        auto bar = foo;
    }
}

/*
TEST_OUTPUT:
---
fail_compilation/fail10378.d(71): Error: function imports.m10378b.foo (int) is not callable using argument types ()
fail_compilation/fail10378.d(81): Error: function imports.m10378b.foo (int) is not callable using argument types ()
---
*/
void test10378b()
{
    // The contiguous local imports can work like DeclDefs scope,
    // but mixed-in import breaks up the group.
    {
        import imports.m10378a;             // foo()
        import imports.m10378b;             // foo(int)
        assert(foo() == 1);
        assert(foo(1) == "a");
    }
    {
        mixin("import imports.m10378a;" ~   // foo()
              "import imports.m10378b;");   // foo(int)
        assert(foo() == 1);
        assert(foo(1) == "a");
    }
    {
        mixin("import imports.m10378a;");   // foo()
        import imports.m10378b;             // foo(int)
        assert(foo() == 1);
        assert(foo(1) == "a");
    }
    {
        import imports.m10378a;             // foo()
        mixin("import imports.m10378b;");   // foo(int) (shadowing)
        assert(foo() == 1);                 // --> error
        assert(foo(1) == "a");
    }

    /* CompileStatement divides the implicit "import scope", because
     * the code string generation might depend on the preceding imports.
     */
    {
        import imports.m10378a;             // foo()
        mixin(makeImportCode());            // foo(int) (shadowing)
        assert(foo() == 1);                 // --> error
        assert(foo(1) == "a");
    }
}
