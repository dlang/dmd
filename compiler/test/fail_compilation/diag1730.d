/*
TEST_OUTPUT:
---
fail_compilation/diag1730.d(73): Error: mutable method `func` is not callable using a `inout` object
fail_compilation/diag1730.d(65):        `diag1730.S.func()` declared here
fail_compilation/diag1730.d(65):        Consider adding `const` or `inout`
fail_compilation/diag1730.d(75): Error: `immutable` method `iFunc` is not callable using a `inout` object
fail_compilation/diag1730.d(67):        `diag1730.S.iFunc() immutable` declared here
fail_compilation/diag1730.d(76): Error: `shared` mutable method `sFunc` is not callable using a non-shared `inout` object
fail_compilation/diag1730.d(68):        `diag1730.S.sFunc() shared` declared here
fail_compilation/diag1730.d(68):        Consider adding `const` or `inout`
fail_compilation/diag1730.d(77): Error: `shared` `const` method `scFunc` is not callable using a non-shared `inout` object
fail_compilation/diag1730.d(69):        `diag1730.S.scFunc() shared const` declared here
fail_compilation/diag1730.d(92): Error: `immutable` method `iFunc` is not callable using a mutable object
fail_compilation/diag1730.d(67):        `diag1730.S.iFunc() immutable` declared here
fail_compilation/diag1730.d(93): Error: `shared` method `sFunc` is not callable using a non-shared object
fail_compilation/diag1730.d(68):        `diag1730.S.sFunc() shared` declared here
fail_compilation/diag1730.d(94): Error: `shared` `const` method `scFunc` is not callable using a non-shared mutable object
fail_compilation/diag1730.d(69):        `diag1730.S.scFunc() shared const` declared here
fail_compilation/diag1730.d(97): Error: mutable method `func` is not callable using a `const` object
fail_compilation/diag1730.d(65):        `diag1730.S.func()` declared here
fail_compilation/diag1730.d(65):        Consider adding `const` or `inout`
fail_compilation/diag1730.d(99): Error: `immutable` method `iFunc` is not callable using a `const` object
fail_compilation/diag1730.d(67):        `diag1730.S.iFunc() immutable` declared here
fail_compilation/diag1730.d(100): Error: `shared` mutable method `sFunc` is not callable using a non-shared `const` object
fail_compilation/diag1730.d(68):        `diag1730.S.sFunc() shared` declared here
fail_compilation/diag1730.d(68):        Consider adding `const` or `inout`
fail_compilation/diag1730.d(101): Error: `shared` `const` method `scFunc` is not callable using a non-shared `const` object
fail_compilation/diag1730.d(69):        `diag1730.S.scFunc() shared const` declared here
fail_compilation/diag1730.d(104): Error: mutable method `func` is not callable using a `immutable` object
fail_compilation/diag1730.d(65):        `diag1730.S.func()` declared here
fail_compilation/diag1730.d(65):        Consider adding `const` or `inout`
fail_compilation/diag1730.d(107): Error: `shared` mutable method `sFunc` is not callable using a `immutable` object
fail_compilation/diag1730.d(68):        `diag1730.S.sFunc() shared` declared here
fail_compilation/diag1730.d(68):        Consider adding `const` or `inout`
fail_compilation/diag1730.d(111): Error: non-shared method `func` is not callable using a `shared` object
fail_compilation/diag1730.d(65):        `diag1730.S.func()` declared here
fail_compilation/diag1730.d(65):        Consider adding `shared`
fail_compilation/diag1730.d(112): Error: non-shared `const` method `cFunc` is not callable using a `shared` mutable object
fail_compilation/diag1730.d(66):        `diag1730.S.cFunc() const` declared here
fail_compilation/diag1730.d(66):        Consider adding `shared`
fail_compilation/diag1730.d(113): Error: `immutable` method `iFunc` is not callable using a `shared` mutable object
fail_compilation/diag1730.d(67):        `diag1730.S.iFunc() immutable` declared here
fail_compilation/diag1730.d(116): Error: non-shared `inout` method `wFunc` is not callable using a `shared` mutable object
fail_compilation/diag1730.d(70):        `diag1730.S.wFunc() inout` declared here
fail_compilation/diag1730.d(70):        Consider adding `shared`
fail_compilation/diag1730.d(118): Error: non-shared mutable method `func` is not callable using a `shared` `const` object
fail_compilation/diag1730.d(65):        `diag1730.S.func()` declared here
fail_compilation/diag1730.d(65):        Consider adding `shared`
fail_compilation/diag1730.d(119): Error: non-shared `const` method `cFunc` is not callable using a `shared` `const` object
fail_compilation/diag1730.d(66):        `diag1730.S.cFunc() const` declared here
fail_compilation/diag1730.d(66):        Consider adding `shared`
fail_compilation/diag1730.d(120): Error: `immutable` method `iFunc` is not callable using a `shared` `const` object
fail_compilation/diag1730.d(67):        `diag1730.S.iFunc() immutable` declared here
fail_compilation/diag1730.d(121): Error: `shared` mutable method `sFunc` is not callable using a `shared` `const` object
fail_compilation/diag1730.d(68):        `diag1730.S.sFunc() shared` declared here
fail_compilation/diag1730.d(68):        Consider adding `const` or `inout`
fail_compilation/diag1730.d(123): Error: non-shared `inout` method `wFunc` is not callable using a `shared` `const` object
fail_compilation/diag1730.d(70):        `diag1730.S.wFunc() inout` declared here
fail_compilation/diag1730.d(70):        Consider adding `shared`
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
