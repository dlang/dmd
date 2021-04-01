// https://issues.dlang.org/show_bug.cgi?id=1654

/*
  TEST_OUTPUT:
  ---
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `char[][]` to `immutable(string)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(char[][], char[][], immutable(string)[])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(char[])[])x ~ y` of type `const(char)[][]` to `char[][]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(char[][], const(char[])[], char[][])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(char[])[])x ~ y` of type `const(char)[][]` to `immutable(string)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(char[][], const(char[])[], immutable(string)[])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(char[])[])x ~ cast(const(char[])[])cast(const(string)[])y` of type `const(char)[][]` to `char[][]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(char[][], immutable(string)[], char[][])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(char[])[])x ~ cast(const(char[])[])cast(const(string)[])y` of type `const(char)[][]` to `immutable(string)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(char[][], immutable(string)[], immutable(string)[])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(char[])[])y` of type `const(char)[][]` to `char[][]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(char[])[], char[][], char[][])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(char[])[])y` of type `const(char)[][]` to `immutable(string)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(char[])[], char[][], immutable(string)[])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `const(char[])[]` to `char[][]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(char[])[], const(char[])[], char[][])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `const(char[])[]` to `immutable(string)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(char[])[], const(char[])[], immutable(string)[])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(char[])[])cast(const(string)[])y` of type `const(char)[][]` to `char[][]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(char[])[], immutable(string)[], char[][])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(char[])[])cast(const(string)[])y` of type `const(char)[][]` to `immutable(string)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(char[])[], immutable(string)[], immutable(string)[])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(char[])[])cast(const(string)[])x ~ cast(const(char[])[])y` of type `const(char)[][]` to `char[][]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(string)[], char[][], char[][])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(char[])[])cast(const(string)[])x ~ cast(const(char[])[])y` of type `const(char)[][]` to `immutable(string)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(string)[], char[][], immutable(string)[])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(char[])[])cast(const(string)[])x ~ y` of type `const(char)[][]` to `char[][]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(string)[], const(char[])[], char[][])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(char[])[])cast(const(string)[])x ~ y` of type `const(char)[][]` to `immutable(string)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(string)[], const(char[])[], immutable(string)[])` error instantiating
fail_compilation/impconv_array.d(179):        instantiated from here: `test!(char[])`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `S2[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S2[], S2[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S2[], const(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S2[], const(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S2[], immutable(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S2[], immutable(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S2)[], S2[], S2[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S2)[], S2[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S2)[], const(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S2)[], const(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S2)[], immutable(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S2)[], immutable(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(S2)[], S2[], S2[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(S2)[], S2[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `S2[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(S2)[], const(S2)[], S2[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(S2)[], const(S2)[], immutable(S2)[])` error instantiating
fail_compilation/impconv_array.d(180):        instantiated from here: `test!(S2)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `S3[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S3[], S3[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S3[], const(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S3[], const(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S3[], immutable(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(S3[], immutable(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S3)[], S3[], S3[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S3)[], S3[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S3)[], const(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S3)[], const(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S3)[], immutable(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(const(S3)[], immutable(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(S3)[], S3[], S3[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(S3)[], S3[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `S3[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(S3)[], const(S3)[], S3[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(153): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(164): Error: template instance `impconv_array.test1!(immutable(S3)[], const(S3)[], immutable(S3)[])` error instantiating
fail_compilation/impconv_array.d(181):        instantiated from here: `test!(S3)`
fail_compilation/impconv_array.d(182): Error: undefined identifier `_`
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

void test1654_ok()
{
    struct S1 { immutable(int)* x; }
    test!(int);                 // ok, no indirections
    test!(string);              // ok, immutable indirections
    test!(S1);                  // ok, immutable indirections
}

void test1654_fail()
{
    struct S2 { int* x; }
    struct S3 { const(int)* x; }
    test!(char[]);              // fail, non-immutable indirections
    test!(S2);                  // fail, non-immutable indirections
    test!(S3);                  // fail, non-immutable indirections
    _;                          // to always trigger an error during development
}
