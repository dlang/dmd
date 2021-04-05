// https://issues.dlang.org/show_bug.cgi?id=1654

/*
  TEST_OUTPUT:
  ---
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ y` of type `S2[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S2[], S2[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S2[], const(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S2[], const(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S2[], immutable(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S2[], immutable(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S2)[], S2[], S2[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S2)[], S2[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S2)[], const(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S2)[], const(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S2)[], immutable(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S2)[], immutable(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(immutable(S2)[], S2[], S2[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(immutable(S2)[], S2[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(immutable(S2)[], const(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(immutable(S2)[], const(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(137):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ y` of type `S3[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S3[], S3[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S3[], const(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S3[], const(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S3[], immutable(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(S3[], immutable(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S3)[], S3[], S3[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S3)[], S3[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S3)[], const(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S3)[], const(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S3)[], immutable(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(const(S3)[], immutable(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(immutable(S3)[], S3[], S3[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(immutable(S3)[], S3[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(immutable(S3)[], const(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(121): Error: template instance `impconv_array.test1!(immutable(S3)[], const(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(140):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(110): Error: cannot implicitly convert expression `x ~ y` of type `const(int)[]` to `short[]`
fail_compilation/impconv_array.d(142): Error: template instance `impconv_array.test1!(const(int)[], const(int)[], short[])` error instantiating
fail_compilation/impconv_array.d(144): Error: undefined identifier `_`
  ---
*/

alias AliasSeq(TList...) = TList;

@safe pure:

void test1(X, Y, Z)()
{
    X x;
    Y y;
    Z z = x ~ y;
}

void test(T)()
{
    alias M = T[];
    alias C = const(T)[];
    alias I = immutable(T)[];
    static foreach (X; AliasSeq!(M, C, I))
        static foreach (Y; AliasSeq!(M, C, I))
            static foreach (Z; AliasSeq!(M, C, I))
                test1!(X,Y,Z)();
}

void test1654()
{
    alias T = int;
    test1!(const(T)[], const(T)[], immutable(T)[]);

    test!(int);                 // ok, no indirections

    test!(string);              // ok

    struct S1 { immutable(int)* x; } // immutable indirections
    test!(S1);                  // ok

    struct S2 { int* x; }       // non-immutable indirections
    test!(S2);                  // fail

    struct S3 { const(int)* x; } // non-immutable indirections
    test!(S3);                  // fail

    test1!(const(int)[], const(int)[], short[]); // fail

    _;                          // to always trigger an error
}
