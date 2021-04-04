// https://issues.dlang.org/show_bug.cgi?id=1654

/*
  TEST_OUTPUT:
  ---
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `S2[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `S2[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `S2[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ cast(const(S2)[])y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S2)[])x ~ y` of type `const(S2)[]` to `immutable(S2)[]`
fail_compilation/impconv_array.d(88): Error: template instance `impconv_array.test!(S2)` error instantiating
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `S3[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `S3[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `S3[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ cast(const(S3)[])y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(75): Error: cannot implicitly convert expression `cast(const(S3)[])x ~ y` of type `const(S3)[]` to `immutable(S3)[]`
fail_compilation/impconv_array.d(91): Error: template instance `impconv_array.test!(S3)` error instantiating
  ---
*/

alias AliasSeq(TList...) = TList;

@safe pure:

void test(T)()
{
    alias M = T[];
    alias C = const(T)[];
    alias I = immutable(T)[];
    static foreach (X; AliasSeq!(M, C, I))
        static foreach (Y; AliasSeq!(M, C, I))
            static foreach (Z; AliasSeq!(M, C, I))
            {
                {
                    X x;
                    Y y;
                    I z = x ~ y;
                }
            }
}

void test1654()
{
    test!(int);                 // ok, no indirections

    struct S1 { immutable(int)* x; } // immutable indirections
    test!(S1);                  // ok

    struct S2 { int* x; }       // non-immutable indirections
    test!(S2);                  // fail

    struct S3 { const(int)* x; } // non-immutable indirections
    test!(S3);                  // fail
}
