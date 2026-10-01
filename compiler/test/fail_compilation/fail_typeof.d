/* TEST_OUTPUT:
---
fail_compilation/fail_typeof.d(9): Error: `this` is not in a class or struct scope
fail_compilation/fail_typeof.d(14): Error: `super` is not in a class scope
fail_compilation/fail_typeof.d(26): Error: `super` is not in a class scope
---
*/

enum E2 : typeof(this)
{
    fail,
}

enum E4 : typeof(super)
{
    fail,
}

struct S1
{
    enum E2 : typeof(this)
    {
        ok = S1(),
    }

    enum E4 : typeof(super)
    {
        fail,
    }
}

class C1
{
    enum E2 : typeof(this)
    {
        ok = new C1,
    }

    enum E4 : typeof(super)
    {
        ok = new C1,
    }
}
