/*
TEST_OUTPUT:
---
fail_compilation/diag_dip1000.d(19): Error: top-level function `testScope` has no `this` to which `scope` can apply
fail_compilation/diag_dip1000.d(20): Error: top-level function `testReturn` has no `this` to which `return` can apply
fail_compilation/diag_dip1000.d(22): Error: top-level function `testTemplateScope` has no `this` to which `scope` can apply
fail_compilation/diag_dip1000.d(23): Error: top-level function `testTemplateReturn` has no `this` to which `return` can apply
fail_compilation/diag_dip1000.d(27): Error: function `diag_dip1000.S.testScope` `static` member has no `this` to which `scope` can apply
fail_compilation/diag_dip1000.d(28): Error: function `diag_dip1000.S.testReturn` `static` member has no `this` to which `return` can apply
fail_compilation/diag_dip1000.d(30): Error: function `diag_dip1000.S.testTemplateScope()().testTemplateScope` `static` member has no `this` to which `scope` can apply
fail_compilation/diag_dip1000.d(31): Error: function `diag_dip1000.S.testTemplateReturn()().testTemplateReturn` `static` member has no `this` to which `return` can apply
fail_compilation/diag_dip1000.d(42): Error: function `diag_dip1000.C.testScope` `static` member has no `this` to which `scope` can apply
fail_compilation/diag_dip1000.d(43): Error: function `diag_dip1000.C.testReturn` `static` member has no `this` to which `return` can apply
fail_compilation/diag_dip1000.d(45): Error: function `diag_dip1000.C.testTemplateScope()().testTemplateScope` `static` member has no `this` to which `scope` can apply
fail_compilation/diag_dip1000.d(46): Error: function `diag_dip1000.C.testTemplateReturn()().testTemplateReturn` `static` member has no `this` to which `return` can apply
---
*/

void testScope() scope { }
void testReturn() return { }

void testTemplateScope()() scope { }
void testTemplateReturn()() return { }

struct S
{
    static void testScope() scope { }
    static void testReturn() return { }

    static void testTemplateScope()() scope { }
    static void testTemplateReturn()() return { }

    void testScope2() scope { }               // Should not emit an error
    void testReturn2() return { }             // Should not emit an error

    void testTemplateScope2()() scope { }     // Should not emit an error
    void testTemplateReturn2()() return { }   // Should not emit an error
}

class C
{
    static void testScope() scope { }
    static void testReturn() return { }

    static void testTemplateScope()() scope { }
    static void testTemplateReturn()() return { }

    void testScope2() scope { }               // Should not emit an error
    void testReturn2() return { }             // Should not emit an error

    void testTemplateScope2()() scope { }     // Should not emit an error
    void testTemplateReturn2()() return { }   // Should not emit an error
}
