template TT4155(T...) { alias T TT4155; }

void test4155()
{
    static int test4155a()
    {
        T getnan(T)() { return T.nan; } // OPcall
        static T getnanu(T)() { return T.nan; } // OPucall
        static T passback(T)(T v) { return v; }

        foreach(T; TT4155!(float, double, real, ifloat, idouble, ireal, cfloat, cdouble, creal))
        {
            auto f = getnan!T();
            if (!__ctfe) // force f into memory
                asm { nop; };

            assert(!(T.nan == 0), T.stringof);
            assert(!(f == 0), T.stringof);
            assert(!(getnan!T == 0), T.stringof);
            assert(!(getnanu!T == 0), T.stringof);

            assert((T.nan != 0), T.stringof);
            assert((f != 0), T.stringof);
            assert((getnan!T != 0), T.stringof);
            assert((getnanu!T != 0), T.stringof);

            assert(passback(0) == 0);
            static if (is(T == cfloat))
               assert(passback(1.0f+1.0fi) == 1.0f+1.0fi);
        }
        return 1;
    }
    auto a = test4155a();
    enum b = test4155a();
}

template TT(T...) { alias T TT; }

void testa()
{
   static T one(T)()
   {
       static if (is(T == float)) return 1.0f;
       else static if (is(T == double)) return 1.0;
       else static if (is(T == real)) return 1.0L;
       else static if (is(T == ifloat)) return 1.0fi;
       else static if (is(T == idouble)) return 1.0i;
       else static if (is(T == ireal)) return 1.0Li;
       else static if (is(T == cfloat)) return one!float() + one!ifloat();
       else static if (is(T == cdouble)) return one!double() + one!idouble();
       else static if (is(T == creal)) return one!real() + one!ireal();
   }
   static T neg(T)()
   {
       static if (is(T == float)) return -1.0f;
       else static if (is(T == double)) return -1.0;
       else static if (is(T == real)) return -1.0L;
       else static if (is(T == ifloat)) return -1.0fi;
       else static if (is(T == idouble)) return -1.0i;
       else static if (is(T == ireal)) return -1.0Li;
       else static if (is(T == cfloat)) return one!float() - one!ifloat();
       else static if (is(T == cdouble)) return one!double() - one!idouble();
       else static if (is(T == creal)) return one!real() - one!ireal();
   }

   static void test(T, U)()
   {
       U conv(T v) { return v; }
       assert(conv(one!T()) == one!U(), T.stringof ~ U.stringof);
       static assert(conv(one!T()) == one!U());
       assert(conv(neg!T()) == neg!U(), T.stringof ~ U.stringof);
       static assert(conv(neg!T()) == neg!U());
   }

   foreach(T; TT!(float, double, real, ifloat, idouble, ireal, cfloat, cdouble, creal))
   {
       foreach(U; TT!(float, double, real, ifloat, idouble, ireal, cfloat, cdouble, creal))
       {
           static if (is(T : U))
           {
               test!(T, U);
           }
       }
   }
}

extern(C) int printf(const char *, ...);

cfloat conv(cdouble val)
{
    return val;
}

cfloat conv2(cdouble val)
{
    printf("%f %f\n", val.re, val.im);
    return val;
}

void testb()
{
    auto a = conv(1.0 + 1.0i);
    printf("%f %f\n", a.re, a.im);
    auto b = conv2(1.0 + 1.0i);
    printf("%f %f\n", b.re, b.im);
    assert(a == b);
}

void main()
{
    test4155();
    testa();
    testb();
}
