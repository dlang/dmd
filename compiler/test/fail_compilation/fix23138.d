/* TEST_OUTPUT:
---
fail_compilation/fix23138.d(16): Error: function `fix23138.C2.foo` cannot override `@safe` method `fix23138.C1.foo` with a `@system` attribute
    override void foo() @system
                  ^
---
 */

class C1 {
    void foo() @safe
    {}
}

class C2 : C1
{
    override void foo() @system
    {}
}
