/* TEST_OUTPUT:
---
fail_compilation/fail_typeof.d(33): Error: undefined identifier `this`
enum E1 : this
^
fail_compilation/fail_typeof.d(38): Error: `this` is not in a class or struct scope
enum E2 : typeof(this)
                 ^
fail_compilation/fail_typeof.d(43): Error: undefined identifier `super`
enum E3 : super
^
fail_compilation/fail_typeof.d(48): Error: `super` is not in a class scope
enum E4 : typeof(super)
                 ^
fail_compilation/fail_typeof.d(55): Error: undefined identifier `this`, did you mean `typeof(this)`?
    enum E1 : this
    ^
fail_compilation/fail_typeof.d(65): Error: undefined identifier `super`
    enum E3 : super
    ^
fail_compilation/fail_typeof.d(70): Error: `super` is not in a class scope
    enum E4 : typeof(super)
                     ^
fail_compilation/fail_typeof.d(78): Error: undefined identifier `this`, did you mean `typeof(this)`?
    enum E1 : this
    ^
fail_compilation/fail_typeof.d(88): Error: undefined identifier `super`, did you mean `typeof(super)`?
    enum E3 : super
    ^
---
*/

enum E1 : this
{
    fail,
}

enum E2 : typeof(this)
{
    fail,
}

enum E3 : super
{
    fail,
}

enum E4 : typeof(super)
{
    fail,
}

struct S1
{
    enum E1 : this
    {
        fail,
    }

    enum E2 : typeof(this)
    {
        ok = S1(),
    }

    enum E3 : super
    {
        fail,
    }

    enum E4 : typeof(super)
    {
        fail,
    }
}

class C1
{
    enum E1 : this
    {
        fail,
    }

    enum E2 : typeof(this)
    {
        ok = new C1,
    }

    enum E3 : super
    {
        fail,
    }

    enum E4 : typeof(super)
    {
        ok = new C1,
    }
}
