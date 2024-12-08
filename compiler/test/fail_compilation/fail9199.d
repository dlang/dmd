// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/fail9199.d(43): Error: function `fail9199.fc` without `this` cannot be `const`
void fc() const {}
     ^
fail_compilation/fail9199.d(44): Error: function `fail9199.fi` without `this` cannot be `immutable`
void fi() immutable {}
     ^
fail_compilation/fail9199.d(45): Error: function `fail9199.fw` without `this` cannot be `inout`
void fw() inout {}
     ^
fail_compilation/fail9199.d(46): Error: function `fail9199.fs` without `this` cannot be `shared`
void fs() shared {}
     ^
fail_compilation/fail9199.d(47): Error: function `fail9199.fsc` without `this` cannot be `shared const`
void fsc() shared const {}
     ^
fail_compilation/fail9199.d(48): Error: function `fail9199.fsw` without `this` cannot be `shared inout`
void fsw() shared inout {}
     ^
fail_compilation/fail9199.d(52): Error: function `fail9199.C.fc` without `this` cannot be `const`
    static void fc() const {}
                ^
fail_compilation/fail9199.d(53): Error: function `fail9199.C.fi` without `this` cannot be `immutable`
    static void fi() immutable {}
                ^
fail_compilation/fail9199.d(54): Error: function `fail9199.C.fw` without `this` cannot be `inout`
    static void fw() inout {}
                ^
fail_compilation/fail9199.d(55): Error: function `fail9199.C.fs` without `this` cannot be `shared`
    static void fs() shared {}
                ^
fail_compilation/fail9199.d(56): Error: function `fail9199.C.fsc` without `this` cannot be `shared const`
    static void fsc() shared const {}
                ^
fail_compilation/fail9199.d(57): Error: function `fail9199.C.fsw` without `this` cannot be `shared inout`
    static void fsw() shared inout {}
                ^
---
*/
void fc() const {}
void fi() immutable {}
void fw() inout {}
void fs() shared {}
void fsc() shared const {}
void fsw() shared inout {}

class C
{
    static void fc() const {}
    static void fi() immutable {}
    static void fw() inout {}
    static void fs() shared {}
    static void fsc() shared const {}
    static void fsw() shared inout {}
}
