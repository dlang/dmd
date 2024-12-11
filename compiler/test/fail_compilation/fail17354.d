/* TEST_OUTPUT:
---
fail_compilation/fail17354.d(16): Error: cannot implicitly override base class method `object.Object.opEquals` with `fail17354.Foo.opEquals`; add `override` attribute
    bool opEquals(const Object) const {return true;}
         ^
fail_compilation/fail17354.d(21): Error: cannot implicitly override base class method `object.Object.opEquals` with `fail17354.Bar.opEquals`; add `override` attribute
    bool opEquals(const Object) const {return true;}
         ^
---
 */

// https://issues.dlang.org/show_bug.cgi?id=17354

final class Foo
{
    bool opEquals(const Object) const {return true;}
}

class Bar
{
    bool opEquals(const Object) const {return true;}
}
