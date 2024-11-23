/* TEST_OUTPUT:
---
fail_compilation/failcontracts.d(33): Error: missing `{ ... }` for function literal
    auto f1 = function() bode;
                         ^
fail_compilation/failcontracts.d(33): Error: semicolon expected following auto declaration, not `bode`
    auto f1 = function() bode;
                         ^
fail_compilation/failcontracts.d(34): Error: function declaration without return type. (Note that constructors are always named `this`)
    auto test1() bode;
              ^
fail_compilation/failcontracts.d(34): Error: no identifier for declarator `test1()`
    auto test1() bode;
                 ^
fail_compilation/failcontracts.d(34): Error: semicolon expected following function declaration, not `bode`
    auto test1() bode;
                 ^
fail_compilation/failcontracts.d(35): Error: semicolon expected following function declaration, not `bode`
    auto test2()() bode;
                   ^
fail_compilation/failcontracts.d(37): Error: unexpected `(` in declarator
    enum : int (int function() bode T);
               ^
fail_compilation/failcontracts.d(37): Error: found `T` when expecting `)`
    enum : int (int function() bode T);
                                    ^
fail_compilation/failcontracts.d(37): Error: expected `{`, not `;` for enum declaration
---
*/

void test()
{
    auto f1 = function() bode;
    auto test1() bode;
    auto test2()() bode;

    enum : int (int function() bode T);
}
