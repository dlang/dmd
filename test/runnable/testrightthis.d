// runnable/traits.d    9091,8972,8971,7027
// runnable/test4.d     test6()

extern(C) int printf(const char*, ...);

template TypeTuple(TL...) { alias TypeTuple = TL; }

/********************************************************/

mixin("struct S1 {"~aggrDecl1~"}");
mixin("class  C1 {"~aggrDecl1~"}");
enum aggrDecl1 =
q{
    alias Type = typeof(this);

    int x = 2;

    void foo()
    {
        static assert( is(typeof(Type.x.offsetof)));
        static assert( is(typeof(Type.x.mangleof)));
        static assert( is(typeof(Type.x.sizeof  )));
        static assert( is(typeof(Type.x.alignof )));
        static assert( is(typeof({ auto n = Type.x.offsetof; })));
        static assert( is(typeof({ auto n = Type.x.mangleof; })));
        static assert( is(typeof({ auto n = Type.x.sizeof;   })));
        static assert( is(typeof({ auto n = Type.x.alignof;  })));
        static assert( is(typeof(Type.x)));
        static assert( is(typeof({ auto n = Type.x; })));
        static assert( __traits(compiles, Type.x));
        static assert( __traits(compiles, { auto n = Type.x; }));

        static assert( is(typeof(x.offsetof)));
        static assert( is(typeof(x.mangleof)));
        static assert( is(typeof(x.sizeof  )));
        static assert( is(typeof(x.alignof )));
        static assert( is(typeof({ auto n = x.offsetof; })));
        static assert( is(typeof({ auto n = x.mangleof; })));
        static assert( is(typeof({ auto n = x.sizeof;   })));
        static assert( is(typeof({ auto n = x.alignof;  })));
        static assert( is(typeof(x)));
        static assert( is(typeof({ auto n = x; })));
        static assert( __traits(compiles, x));
        static assert( __traits(compiles, { auto n = x; }));

        with (this)
        {
            static assert( is(typeof(x.offsetof)));
            static assert( is(typeof(x.mangleof)));
            static assert( is(typeof(x.sizeof  )));
            static assert( is(typeof(x.alignof )));
            static assert( is(typeof({ auto n = x.offsetof; })));
            static assert( is(typeof({ auto n = x.mangleof; })));
            static assert( is(typeof({ auto n = x.sizeof;   })));
            static assert( is(typeof({ auto n = x.alignof;  })));
            static assert( is(typeof(x)));
            static assert( is(typeof({ auto n = x; })));
            static assert( __traits(compiles, x));
            static assert( __traits(compiles, { auto n = x; }));
        }
    }

    static void bar()
    {
        static assert( is(typeof(Type.x.offsetof)));
        static assert( is(typeof(Type.x.mangleof)));
        static assert( is(typeof(Type.x.sizeof  )));
        static assert( is(typeof(Type.x.alignof )));
        static assert( is(typeof({ auto n = Type.x.offsetof; })));
        static assert( is(typeof({ auto n = Type.x.mangleof; })));
        static assert( is(typeof({ auto n = Type.x.sizeof;   })));
        static assert( is(typeof({ auto n = Type.x.alignof;  })));
        static assert( is(typeof(Type.x)));
        static assert(!is(typeof({ auto n = Type.x; })));
        static assert( __traits(compiles, Type.x));
        static assert(!__traits(compiles, { auto n = Type.x; }));

        static assert( is(typeof(x.offsetof)));
        static assert( is(typeof(x.mangleof)));
        static assert( is(typeof(x.sizeof  )));
        static assert( is(typeof(x.alignof )));
        static assert( is(typeof({ auto n = x.offsetof; })));
        static assert( is(typeof({ auto n = x.mangleof; })));
        static assert( is(typeof({ auto n = x.sizeof;   })));
        static assert( is(typeof({ auto n = x.alignof;  })));
        static assert( is(typeof(x)));
        static assert(!is(typeof({ auto n = x; })));
        static assert( __traits(compiles, x));
        static assert(!__traits(compiles, { auto n = x; }));

        Type t;
        with (t)
        {
            static assert( is(typeof(x.offsetof)));
            static assert( is(typeof(x.mangleof)));
            static assert( is(typeof(x.sizeof  )));
            static assert( is(typeof(x.alignof )));
            static assert( is(typeof({ auto n = x.offsetof; })));
            static assert( is(typeof({ auto n = x.mangleof; })));
            static assert( is(typeof({ auto n = x.sizeof;   })));
            static assert( is(typeof({ auto n = x.alignof;  })));
            static assert( is(typeof(x)));
            static assert( is(typeof({ auto n = x; })));
            static assert( __traits(compiles, x));
            static assert( __traits(compiles, { auto n = x; }));
        }
    }
};
void test1()
{
    foreach (Type; TypeTuple!(S1, C1))
    {
        static assert( is(typeof(Type.x.offsetof)));
        static assert( is(typeof(Type.x.mangleof)));
        static assert( is(typeof(Type.x.sizeof  )));
        static assert( is(typeof(Type.x.alignof )));
        static assert( is(typeof({ auto n = Type.x.offsetof; })));
        static assert( is(typeof({ auto n = Type.x.mangleof; })));
        static assert( is(typeof({ auto n = Type.x.sizeof;   })));
        static assert( is(typeof({ auto n = Type.x.alignof;  })));
        static assert( is(typeof(Type.x)));
        static assert(!is(typeof({ auto n = Type.x; })));
        static assert( __traits(compiles, Type.x));
        static assert(!__traits(compiles, { auto n = Type.x; }));

        Type t;
        static assert( is(typeof(t.x.offsetof)));
        static assert( is(typeof(t.x.mangleof)));
        static assert( is(typeof(t.x.sizeof  )));
        static assert( is(typeof(t.x.alignof )));
        static assert( is(typeof({ auto n = t.x.offsetof; })));
        static assert( is(typeof({ auto n = t.x.mangleof; })));
        static assert( is(typeof({ auto n = t.x.sizeof;   })));
        static assert( is(typeof({ auto n = t.x.alignof;  })));
        static assert( is(typeof(t.x)));
        static assert( is(typeof({ auto n = t.x; })));
        static assert( __traits(compiles, t.x));
        static assert( __traits(compiles, { auto n = t.x; }));

        with (t)
        {
            static assert( is(typeof(x.offsetof)));
            static assert( is(typeof(x.mangleof)));
            static assert( is(typeof(x.sizeof  )));
            static assert( is(typeof(x.alignof )));
            static assert( is(typeof({ auto n = x.offsetof; })));
            static assert( is(typeof({ auto n = x.mangleof; })));
            static assert( is(typeof({ auto n = x.sizeof;   })));
            static assert( is(typeof({ auto n = x.alignof;  })));
            static assert( is(typeof(x)));
            static assert( is(typeof({ auto n = x; })));
            static assert( __traits(compiles, x));
            static assert( __traits(compiles, { auto n = x; }));
        }
    }
}

/********************************************************/

void test2()
{
    struct S
    {
        int val;
        int[] arr;
        int[int] aar;

        void foo() {}
        void boo()() {}

        static void test()
        {
            static assert(!__traits(compiles, S.foo()));
            static assert(!__traits(compiles, S.boo()));
            static assert(!__traits(compiles, foo()));
            static assert(!__traits(compiles, boo()));
        }
    }
    int v;
    int[] a;
    void f(int n) {}

    static assert( __traits(compiles, S.val));  // 'S.val' is treated just a symbol
    static assert(!__traits(compiles, { int n = S.val; }));
    static assert(!__traits(compiles, f(S.val)));

    static assert(!__traits(compiles, v = S.val) && !__traits(compiles, S.val = v));

    static assert(!__traits(compiles, 1 + S.val) && !__traits(compiles, S.val + 1));
    static assert(!__traits(compiles, 1 - S.val) && !__traits(compiles, S.val - 1));
    static assert(!__traits(compiles, 1 * S.val) && !__traits(compiles, S.val * 1));
    static assert(!__traits(compiles, 1 / S.val) && !__traits(compiles, S.val / 1));
    static assert(!__traits(compiles, 1 % S.val) && !__traits(compiles, S.val % 1));
    static assert(!__traits(compiles, 1 ~ S.arr) && !__traits(compiles, S.arr ~ 1));

    static assert(!__traits(compiles, 1 & S.val) && !__traits(compiles, S.val & 1));
    static assert(!__traits(compiles, 1 | S.val) && !__traits(compiles, S.val | 1));
    static assert(!__traits(compiles, 1 ^ S.val) && !__traits(compiles, S.val ^ 1));
    static assert(!__traits(compiles, 1 ~ S.val) && !__traits(compiles, S.val ~ 1));

    static assert(!__traits(compiles, 1 ^^ S.val) && !__traits(compiles, S.val ^^ 1));
    static assert(!__traits(compiles, 1 << S.val) && !__traits(compiles, S.val << 1));
    static assert(!__traits(compiles, 1 >> S.val) && !__traits(compiles, S.val >> 1));
    static assert(!__traits(compiles, 1 >>>S.val) && !__traits(compiles, S.val >>>1));
    static assert(!__traits(compiles, 1 && S.val) && !__traits(compiles, S.val && 1));
    static assert(!__traits(compiles, 1 || S.val) && !__traits(compiles, S.val || 1));
    static assert(!__traits(compiles, 1 in S.aar) && !__traits(compiles, S.val || [1:1]));

    static assert(!__traits(compiles, 1 <= S.val) && !__traits(compiles, S.val <= 1));
    static assert(!__traits(compiles, 1 == S.val) && !__traits(compiles, S.val == 1));
    static assert(!__traits(compiles, 1 is S.val) && !__traits(compiles, S.val is 1));

    static assert(!__traits(compiles, 1? 1:S.val) && !__traits(compiles, 1? S.val:1));
    static assert(!__traits(compiles, (1, S.val)) && !__traits(compiles, (S.val, 1)));

    static assert(!__traits(compiles, &S.val));
    static assert(!__traits(compiles, S.arr[0]) && !__traits(compiles, [1,2][S.val]));
    static assert(!__traits(compiles, S.val++) && !__traits(compiles, S.val--));
    static assert(!__traits(compiles, ++S.val) && !__traits(compiles, --S.val));

    static assert(!__traits(compiles, v += S.val) && !__traits(compiles, S.val += 1));
    static assert(!__traits(compiles, v -= S.val) && !__traits(compiles, S.val -= 1));
    static assert(!__traits(compiles, v *= S.val) && !__traits(compiles, S.val *= 1));
    static assert(!__traits(compiles, v /= S.val) && !__traits(compiles, S.val /= 1));
    static assert(!__traits(compiles, v %= S.val) && !__traits(compiles, S.val %= 1));
    static assert(!__traits(compiles, v &= S.val) && !__traits(compiles, S.val &= 1));
    static assert(!__traits(compiles, v |= S.val) && !__traits(compiles, S.val |= 1));
    static assert(!__traits(compiles, v ^= S.val) && !__traits(compiles, S.val ^= 1));
    static assert(!__traits(compiles, a ~= S.val) && !__traits(compiles, S.arr ~= 1));

    static assert(!__traits(compiles, v ^^= S.val) && !__traits(compiles, S.val ^^= 1));
    static assert(!__traits(compiles, v <<= S.val) && !__traits(compiles, S.val <<= 1));
    static assert(!__traits(compiles, v >>= S.val) && !__traits(compiles, S.val >>= 1));
    static assert(!__traits(compiles, v >>>=S.val) && !__traits(compiles, S.val >>>=1));

    static assert(!__traits(compiles, { auto x = 1 + S.val; }) && !__traits(compiles, { auto x = S.val + 1; }));
    static assert(!__traits(compiles, { auto x = 1 - S.val; }) && !__traits(compiles, { auto x = S.val - 1; }));
    static assert(!__traits(compiles, { auto x = S.arr ~ 1; }) && !__traits(compiles, { auto x = 1 ~ S.arr; }));

    static assert(!__traits(compiles, S.foo()));
    static assert(!__traits(compiles, S.boo()));
    S.test();
    alias foo = S.foo;
    alias boo = S.boo;
    static assert(!__traits(compiles, foo()));
    static assert(!__traits(compiles, boo()));

//  static assert(S.val);

    struct SW { int a; }
    class CW { int a; }
    static assert(!__traits(compiles, { with (SW) { int n = a; } }));
    static assert(!__traits(compiles, { with (CW) { int n = a; } }));
}

/********************************************************/

struct S3
{
    struct T3 { int val; void foo() {} }
    T3 member;
    alias member this;

    static void test()
    {
        static assert(!__traits(compiles,   S3.val = 1   ));
        static assert(!__traits(compiles, { S3.val = 1; }));
        static assert(!__traits(compiles,   T3.val = 1   ));
        static assert(!__traits(compiles, { T3.val = 1; }));
        static assert(!__traits(compiles,   __traits(getMember, S3, "val") = 1   ));
        static assert(!__traits(compiles, { __traits(getMember, S3, "val") = 1; }));
        static assert(!__traits(compiles,   __traits(getMember, T3, "val") = 1   ));
        static assert(!__traits(compiles, { __traits(getMember, T3, "val") = 1; }));

        static assert(!__traits(compiles,   S3.foo()   ));
        static assert(!__traits(compiles, { S3.foo(); }));
        static assert(!__traits(compiles,   T3.foo()   ));
        static assert(!__traits(compiles, { T3.foo(); }));
        static assert(!__traits(compiles,   __traits(getMember, S3, "foo")()   ));
        static assert(!__traits(compiles, { __traits(getMember, S3, "foo")(); }));
        static assert(!__traits(compiles,   __traits(getMember, T3, "foo")()   ));
        static assert(!__traits(compiles, { __traits(getMember, T3, "foo")(); }));
        static assert(!__traits(compiles,   __traits(getOverloads, S3, "foo")[0]()   ));
        static assert(!__traits(compiles, { __traits(getOverloads, S3, "foo")[0](); }));
        static assert(!__traits(compiles,   __traits(getOverloads, T3, "foo")[0]()   ));
        static assert(!__traits(compiles, { __traits(getOverloads, T3, "foo")[0](); }));
    }
}

void test3()
{
}

/********************************************************/

void test4()
{
    static struct R
    {
        void opIndex(int) {}
        void opSlice() {}
        void opSlice(int, int) {}
        int opDollar() { return 1; }
        alias length = opDollar;
    }

    R val;
    static struct S
    {
        R val;
        void foo()
        {
            static assert(__traits(compiles, val[1]));              // TypeSArray
            static assert(__traits(compiles, val[]));               // TypeDArray
            static assert(__traits(compiles, val[0..val.length]));  // TypeSlice
        }
    }
}

/********************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();

    printf("Success\n");
    return 0;
}
