/*
TEST_OUTPUT:
---
fail_compilation/diag1730.d(121): Error: mutable method `diag1730.S.func` is not callable using a `inout` object
        s.func();   // ng
              ^
fail_compilation/diag1730.d(113):        Consider adding `const` or `inout` here
    void func() { }
         ^
fail_compilation/diag1730.d(123): Error: `immutable` method `diag1730.S.iFunc` is not callable using a `inout` object
        s.iFunc();  // ng
               ^
fail_compilation/diag1730.d(124): Error: `shared` mutable method `diag1730.S.sFunc` is not callable using a non-shared `inout` object
        s.sFunc();  // ng
               ^
fail_compilation/diag1730.d(116):        Consider adding `const` or `inout` here
    void sFunc() shared { }
         ^
fail_compilation/diag1730.d(125): Error: `shared` `const` method `diag1730.S.scFunc` is not callable using a non-shared `inout` object
        s.scFunc(); // ng
                ^
fail_compilation/diag1730.d(140): Error: `immutable` method `diag1730.S.iFunc` is not callable using a mutable object
    obj.iFunc();   // ng
             ^
fail_compilation/diag1730.d(141): Error: `shared` method `diag1730.S.sFunc` is not callable using a non-shared object
    obj.sFunc();   // ng
             ^
fail_compilation/diag1730.d(142): Error: `shared` `const` method `diag1730.S.scFunc` is not callable using a non-shared mutable object
    obj.scFunc();  // ng
              ^
fail_compilation/diag1730.d(145): Error: mutable method `diag1730.S.func` is not callable using a `const` object
    cObj.func();   // ng
             ^
fail_compilation/diag1730.d(113):        Consider adding `const` or `inout` here
    void func() { }
         ^
fail_compilation/diag1730.d(147): Error: `immutable` method `diag1730.S.iFunc` is not callable using a `const` object
    cObj.iFunc();  // ng
              ^
fail_compilation/diag1730.d(148): Error: `shared` mutable method `diag1730.S.sFunc` is not callable using a non-shared `const` object
    cObj.sFunc();  // ng
              ^
fail_compilation/diag1730.d(116):        Consider adding `const` or `inout` here
    void sFunc() shared { }
         ^
fail_compilation/diag1730.d(149): Error: `shared` `const` method `diag1730.S.scFunc` is not callable using a non-shared `const` object
    cObj.scFunc(); // ng
               ^
fail_compilation/diag1730.d(152): Error: mutable method `diag1730.S.func` is not callable using a `immutable` object
    iObj.func();   // ng
             ^
fail_compilation/diag1730.d(113):        Consider adding `const` or `inout` here
    void func() { }
         ^
fail_compilation/diag1730.d(155): Error: `shared` mutable method `diag1730.S.sFunc` is not callable using a `immutable` object
    iObj.sFunc();  // ng
              ^
fail_compilation/diag1730.d(116):        Consider adding `const` or `inout` here
    void sFunc() shared { }
         ^
fail_compilation/diag1730.d(159): Error: non-shared method `diag1730.S.func` is not callable using a `shared` object
    sObj.func();   // ng
             ^
fail_compilation/diag1730.d(113):        Consider adding `shared` here
    void func() { }
         ^
fail_compilation/diag1730.d(160): Error: non-shared `const` method `diag1730.S.cFunc` is not callable using a `shared` mutable object
    sObj.cFunc();  // ng
              ^
fail_compilation/diag1730.d(114):        Consider adding `shared` here
    void cFunc() const { }
         ^
fail_compilation/diag1730.d(161): Error: `immutable` method `diag1730.S.iFunc` is not callable using a `shared` mutable object
    sObj.iFunc();  // ng
              ^
fail_compilation/diag1730.d(164): Error: non-shared `inout` method `diag1730.S.wFunc` is not callable using a `shared` mutable object
    sObj.wFunc();  // ng
              ^
fail_compilation/diag1730.d(118):        Consider adding `shared` here
    void wFunc() inout { }
         ^
fail_compilation/diag1730.d(166): Error: non-shared mutable method `diag1730.S.func` is not callable using a `shared` `const` object
    scObj.func();  // ng
              ^
fail_compilation/diag1730.d(113):        Consider adding `shared` here
    void func() { }
         ^
fail_compilation/diag1730.d(167): Error: non-shared `const` method `diag1730.S.cFunc` is not callable using a `shared` `const` object
    scObj.cFunc(); // ng
               ^
fail_compilation/diag1730.d(114):        Consider adding `shared` here
    void cFunc() const { }
         ^
fail_compilation/diag1730.d(168): Error: `immutable` method `diag1730.S.iFunc` is not callable using a `shared` `const` object
    scObj.iFunc(); // ng
               ^
fail_compilation/diag1730.d(169): Error: `shared` mutable method `diag1730.S.sFunc` is not callable using a `shared` `const` object
    scObj.sFunc(); // ng
               ^
fail_compilation/diag1730.d(116):        Consider adding `const` or `inout` here
    void sFunc() shared { }
         ^
fail_compilation/diag1730.d(171): Error: non-shared `inout` method `diag1730.S.wFunc` is not callable using a `shared` `const` object
    scObj.wFunc(); // ng
               ^
fail_compilation/diag1730.d(118):        Consider adding `shared` here
    void wFunc() inout { }
         ^
---
*/
struct S
{
    void func() { }
    void cFunc() const { }
    void iFunc() immutable { }
    void sFunc() shared { }
    void scFunc() shared const { }
    void wFunc() inout { }
    static void test(inout(S) s)
    {
        s.func();   // ng
        s.cFunc();
        s.iFunc();  // ng
        s.sFunc();  // ng
        s.scFunc(); // ng
        s.wFunc();
    }
}

void main()
{
    S obj;
    const(S) cObj;
    immutable(S) iObj;
    shared(S) sObj;
    shared(const(S)) scObj;

    obj.func();
    obj.cFunc();
    obj.iFunc();   // ng
    obj.sFunc();   // ng
    obj.scFunc();  // ng
    obj.wFunc();

    cObj.func();   // ng
    cObj.cFunc();
    cObj.iFunc();  // ng
    cObj.sFunc();  // ng
    cObj.scFunc(); // ng
    cObj.wFunc();

    iObj.func();   // ng
    iObj.cFunc();
    iObj.iFunc();
    iObj.sFunc();  // ng
    iObj.scFunc();
    iObj.wFunc();

    sObj.func();   // ng
    sObj.cFunc();  // ng
    sObj.iFunc();  // ng
    sObj.sFunc();
    sObj.scFunc();
    sObj.wFunc();  // ng

    scObj.func();  // ng
    scObj.cFunc(); // ng
    scObj.iFunc(); // ng
    scObj.sFunc(); // ng
    scObj.scFunc();
    scObj.wFunc(); // ng
}
