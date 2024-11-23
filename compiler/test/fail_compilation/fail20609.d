/*
  TEST_OUTPUT:
  ---
fail_compilation/fail20609.d(44): Error: none of the overloads of `this` are callable using argument types `(int)`
void test1() { auto f = Foo(42); }
                           ^
fail_compilation/fail20609.d(41):        Candidate is: `fail20609.Foo.this(string[] args)`
    this(string[] args) {}
    ^
fail_compilation/fail20609.d(45): Error: none of the overloads of `this` are callable using argument types `(int)`
deprecated void test2() { auto f = Foo(42); }
                                      ^
fail_compilation/fail20609.d(40):        Candidates are: `fail20609.Foo.this(Object __param_0)`
    deprecated this(Object) {}
               ^
fail_compilation/fail20609.d(41):                        `fail20609.Foo.this(string[] args)`
    this(string[] args) {}
    ^
fail_compilation/fail20609.d(55): Error: none of the overloads of `this` are callable using argument types `(int)`
void test3() { auto f = WhoDoesThat(42); }
                                   ^
fail_compilation/fail20609.d(55):        All possible candidates are marked as `deprecated` or `@disable`
fail_compilation/fail20609.d(61): Error: undefined identifier `deprecatedTypo_`
void test4 () { deprecatedTypo_("42"); }
                ^
fail_compilation/fail20609.d(62): Error: undefined identifier `deprecatedTypo_`, did you mean function `deprecatedTypo`?
deprecated void test5 () { deprecatedTypo_("42"); }
                           ^
fail_compilation/fail20609.d(63): Error: undefined identifier `disabledTypo_`
void test6 () { disabledTypo_("42"); }
                ^
---
 */

// Only show `this(string[])` in non-deprecated context.
// Show both `this(string[])` and ` this(Object)` in deprecated context.
struct Foo
{
    @disable this();
    deprecated this(Object) {}
    this(string[] args) {}
}

void test1() { auto f = Foo(42); }
deprecated void test2() { auto f = Foo(42); }

// Make sure we do not show a message promising candidates,
// then no candidates in the special case where nothing
// would be usable
struct WhoDoesThat
{
    @disable this();
    deprecated this(Object) {}
}
void test3() { auto f = WhoDoesThat(42); }

// Make sure we don't suggest disabled or deprecated functions
deprecated void deprecatedTypo () {}
@disable   void disabledTypo   () {}

void test4 () { deprecatedTypo_("42"); }
deprecated void test5 () { deprecatedTypo_("42"); }
void test6 () { disabledTypo_("42"); }
