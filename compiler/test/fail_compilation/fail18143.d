/*
TEST_OUTPUT:
---
fail_compilation/fail18143.d(36): Error: variable `fail18143.S.a` cannot modify parameter `this` in contract
    in { a = n; }   // error, modifying this.a in contract
         ^
fail_compilation/fail18143.d(37): Error: variable `fail18143.S.a` cannot modify parameter `this` in contract
    out { a = n; }  // error, modifying this.a in contract
          ^
fail_compilation/fail18143.d(41): Error: variable `fail18143.S.a` cannot modify parameter `this` in contract
    in { a = n; }   // error, modifying this.a in contract
         ^
fail_compilation/fail18143.d(42): Error: variable `fail18143.S.a` cannot modify parameter `this` in contract
    out { a = n; }  // error, modifying this.a in contract
          ^
fail_compilation/fail18143.d(51): Error: variable `fail18143.C.a` cannot modify parameter `this` in contract
    in { a = n; }   // error, modifying this.a in contract
         ^
fail_compilation/fail18143.d(52): Error: variable `fail18143.C.a` cannot modify parameter `this` in contract
    out { a = n; }  // error, modifying this.a in contract
          ^
fail_compilation/fail18143.d(56): Error: variable `fail18143.C.a` cannot modify parameter `this` in contract
    in { a = n; }   // error, modifying this.a in contract
         ^
fail_compilation/fail18143.d(57): Error: variable `fail18143.C.a` cannot modify parameter `this` in contract
    out { a = n; }  // error, modifying this.a in contract
          ^
---
*/

struct S
{
    int a;

    this(int n)
    in { a = n; }   // error, modifying this.a in contract
    out { a = n; }  // error, modifying this.a in contract
    do { }

    void foo(int n)
    in { a = n; }   // error, modifying this.a in contract
    out { a = n; }  // error, modifying this.a in contract
    do { }
}

class C
{
    int a;

    this(int n)
    in { a = n; }   // error, modifying this.a in contract
    out { a = n; }  // error, modifying this.a in contract
    do { }

    void foo(int n)
    in { a = n; }   // error, modifying this.a in contract
    out { a = n; }  // error, modifying this.a in contract
    do { }
}
