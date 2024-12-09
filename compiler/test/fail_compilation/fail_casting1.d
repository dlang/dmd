// REQUIRED_SRGS: -o-


// references
alias P = int*;             P p;
alias FP = int function();  FP fp;
alias DG = int delegate();  DG dg;
alias DA = int[];           DA da;
alias AA = int[int];        AA aa;
class C {}                  C c;
alias N = typeof(null);     N n;

// values
alias SA = int[1];          SA sa;
struct S {}                 S s;
                            int i;
                            double f;


/*
TEST_OUTPUT:
---
fail_compilation/fail_casting1.d(253): Error: cannot cast expression `p` of type `int*` to `int[1]`
    { auto x = cast(SA) p; }        // Reject (Bugzilla 14596)
                        ^
fail_compilation/fail_casting1.d(254): Error: cannot cast expression `fp` of type `int function()` to `int[1]`
    { auto x = cast(SA)fp; }        // Reject (Bugzilla 14596) (FP is Tpointer)
                       ^
fail_compilation/fail_casting1.d(255): Error: cannot cast expression `dg` of type `int delegate()` to `int[1]`
    { auto x = cast(SA)dg; }        // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(256): Error: cannot cast expression `da` of type `int[]` to `int[1]`
    { auto x = cast(SA)da; }        // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(257): Error: cannot cast expression `aa` of type `int[int]` to `int[1]`
    { auto x = cast(SA)aa; }        // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(258): Error: cannot cast expression `c` of type `fail_casting1.C` to `int[1]`
    { auto x = cast(SA) c; }        // Reject (Bugzilla 10646)
                        ^
fail_compilation/fail_casting1.d(259): Error: cannot cast expression `n` of type `typeof(null)` to `int[1]`
    { auto x = cast(SA) n; }        // Reject (Bugzilla 8179)
                        ^
fail_compilation/fail_casting1.d(263): Error: cannot cast expression `sa` of type `int[1]` to `int delegate()`
    { auto x = cast(DG)sa; }        // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(265): Error: cannot cast expression `sa` of type `int[1]` to `double[]` since sizes don't line up
    { auto x = cast(double[])sa; }  // Reject (from e2ir)
                             ^
fail_compilation/fail_casting1.d(266): Error: cannot cast expression `sa` of type `int[1]` to `int[int]`
    { auto x = cast(AA)sa; }        // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(267): Error: cannot cast expression `sa` of type `int[1]` to `fail_casting1.C`
    { auto x = cast( C)sa; }        // Reject (Bugzilla 10646)
                       ^
fail_compilation/fail_casting1.d(268): Error: cannot cast expression `sa` of type `int[1]` to `typeof(null)`
    { auto x = cast( N)sa; }        // Reject (Bugzilla 8179)
                       ^
fail_compilation/fail_casting1.d(273): Error: cannot cast expression `p` of type `int*` to `S`
    { auto x = cast( S) p; }        // Reject (Bugzilla 13959)
                        ^
fail_compilation/fail_casting1.d(274): Error: cannot cast expression `fp` of type `int function()` to `S`
    { auto x = cast( S)fp; }        // Reject (Bugzilla 13959) (FP is Tpointer)
                       ^
fail_compilation/fail_casting1.d(275): Error: cannot cast expression `dg` of type `int delegate()` to `S`
    { auto x = cast( S)dg; }        // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(276): Error: cannot cast expression `da` of type `int[]` to `S`
    { auto x = cast( S)da; }        // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(277): Error: cannot cast expression `aa` of type `int[int]` to `S`
    { auto x = cast( S)aa; }        // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(278): Error: cannot cast expression `c` of type `fail_casting1.C` to `S`
    { auto x = cast( S) c; }        // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(279): Error: cannot cast expression `n` of type `typeof(null)` to `S`
    { auto x = cast( S) n; }        // Reject (Bugzilla 9904)
                        ^
fail_compilation/fail_casting1.d(280): Error: cannot cast expression `s` of type `S` to `int*`
    { auto x = cast( P) s; }        // Reject (Bugzilla 13959)
                        ^
fail_compilation/fail_casting1.d(281): Error: cannot cast expression `s` of type `S` to `int function()`
    { auto x = cast(FP) s; }        // Reject (Bugzilla 13959) (FP is Tpointer)
                        ^
fail_compilation/fail_casting1.d(282): Error: cannot cast expression `s` of type `S` to `int delegate()`
    { auto x = cast(DG) s; }        // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(283): Error: cannot cast expression `s` of type `S` to `int[]`
    { auto x = cast(DA) s; }        // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(284): Error: cannot cast expression `s` of type `S` to `int[int]`
    { auto x = cast(AA) s; }        // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(285): Error: cannot cast expression `s` of type `S` to `fail_casting1.C`
    { auto x = cast( C) s; }        // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(286): Error: cannot cast expression `s` of type `S` to `typeof(null)`
    { auto x = cast( N) s; }        // Reject (Bugzilla 9904)
                        ^
fail_compilation/fail_casting1.d(293): Error: cannot cast expression `p` of type `int*` to `int delegate()`
    { auto x = cast(DG) p; }    // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(294): Error: cannot cast expression `p` of type `int*` to `int[]`
    { auto x = cast(DA) p; }    // Reject (Bugzilla 14596)
                        ^
fail_compilation/fail_casting1.d(297): Error: cannot cast expression `p` of type `int*` to `typeof(null)`
    { auto x = cast( N) p; }    // Reject (Bugzilla 14629)
                        ^
fail_compilation/fail_casting1.d(301): Error: cannot cast expression `fp` of type `int function()` to `int delegate()`
    { auto x = cast(DG)fp; }    // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(302): Error: cannot cast expression `fp` of type `int function()` to `int[]`
    { auto x = cast(DA)fp; }    // Reject (Bugzilla 14596)
                       ^
fail_compilation/fail_casting1.d(305): Error: cannot cast expression `fp` of type `int function()` to `typeof(null)`
    { auto x = cast( N)fp; }    // Reject (Bugzilla 14629)
                       ^
fail_compilation/fail_casting1.d(307): Deprecation: casting from int delegate() to int* is deprecated
    { auto x = cast( P)dg; }    // Deprecated (equivalent with: cast( P)dg.ptr;)
                       ^
fail_compilation/fail_casting1.d(308): Deprecation: casting from int delegate() to int function() is deprecated
    { auto x = cast(FP)dg; }    // Deprecated (equivalent with: cast(FP)dg.ptr;)
                       ^
fail_compilation/fail_casting1.d(310): Error: cannot cast expression `dg` of type `int delegate()` to `int[]`
    { auto x = cast(DA)dg; }    // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(311): Error: cannot cast expression `dg` of type `int delegate()` to `int[int]`
    { auto x = cast(AA)dg; }    // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(312): Error: cannot cast expression `dg` of type `int delegate()` to `fail_casting1.C`
    { auto x = cast( C)dg; }    // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(313): Error: cannot cast expression `dg` of type `int delegate()` to `typeof(null)`
    { auto x = cast( N)dg; }    // Reject (Bugzilla 14629)
                       ^
fail_compilation/fail_casting1.d(325): Error: cannot cast expression `da` of type `int[]` to `int delegate()`
    { auto x = cast(DG)da; }    // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(327): Error: cannot cast expression `da` of type `int[]` to `int[int]`
    { auto x = cast(AA)da; }    // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(328): Error: cannot cast expression `da` of type `int[]` to `fail_casting1.C`
    { auto x = cast( C)da; }    // Reject (Bugzilla 10646)
                       ^
fail_compilation/fail_casting1.d(329): Error: cannot cast expression `da` of type `int[]` to `typeof(null)`
    { auto x = cast( N)da; }    // Reject (Bugzilla 14629)
                       ^
fail_compilation/fail_casting1.d(333): Error: cannot cast expression `aa` of type `int[int]` to `int delegate()`
    { auto x = cast(DG)aa; }    // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(334): Error: cannot cast expression `aa` of type `int[int]` to `int[]`
    { auto x = cast(DA)aa; }    // Reject (from e2ir)
                       ^
fail_compilation/fail_casting1.d(337): Error: cannot cast expression `aa` of type `int[int]` to `typeof(null)`
    { auto x = cast( N)aa; }    // Reject (Bugzilla 14629)
                       ^
fail_compilation/fail_casting1.d(341): Error: cannot cast expression `c` of type `fail_casting1.C` to `int delegate()`
    { auto x = cast(DG) c; }    // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(342): Error: cannot cast expression `c` of type `fail_casting1.C` to `int[]`
    { auto x = cast(DA) c; }    // Reject (Bugzilla 10646)
                        ^
fail_compilation/fail_casting1.d(345): Error: cannot cast expression `c` of type `fail_casting1.C` to `typeof(null)`
    { auto x = cast( N) c; }    // Reject (Bugzilla 14629)
                        ^
fail_compilation/fail_casting1.d(352): Error: cannot cast expression `0` of type `int` to `int delegate()`
    { auto x = cast(DG) 0; }    // Reject (from constfold)
                        ^
fail_compilation/fail_casting1.d(353): Error: cannot cast expression `0` of type `int` to `int[]`
    { auto x = cast(DA) 0; }    // Reject (Bugzilla 11484)
                        ^
fail_compilation/fail_casting1.d(354): Error: cannot cast expression `0` of type `int` to `int[1]`
    { auto x = cast(SA) 0; }    // Reject (Bugzilla 11484)
                        ^
fail_compilation/fail_casting1.d(355): Error: cannot cast expression `0` of type `int` to `int[int]`
    { auto x = cast(AA) 0; }    // Reject (from constfold)
                        ^
fail_compilation/fail_casting1.d(356): Error: cannot cast expression `0` of type `int` to `fail_casting1.C`
    { auto x = cast( C) 0; }    // Reject (Bugzilla 11485)
                        ^
fail_compilation/fail_casting1.d(357): Error: cannot cast expression `0` of type `int` to `typeof(null)`
    { auto x = cast( N) 0; }    // Reject (from constfold)
                        ^
fail_compilation/fail_casting1.d(361): Error: cannot cast expression `i` of type `int` to `int delegate()`
    { auto x = cast(DG) i; }    // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(362): Error: cannot cast expression `i` of type `int` to `int[]`
    { auto x = cast(DA) i; }    // Reject (Bugzilla 11484)
                        ^
fail_compilation/fail_casting1.d(363): Error: cannot cast expression `i` of type `int` to `int[1]`
    { auto x = cast(SA) i; }    // Reject (Bugzilla 11484)
                        ^
fail_compilation/fail_casting1.d(364): Error: cannot cast expression `i` of type `int` to `int[int]`
    { auto x = cast(AA) i; }    // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(365): Error: cannot cast expression `i` of type `int` to `fail_casting1.C`
    { auto x = cast( C) i; }    // Reject (Bugzilla 11485)
                        ^
fail_compilation/fail_casting1.d(366): Error: cannot cast expression `i` of type `int` to `typeof(null)`
    { auto x = cast( N) i; }    // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(370): Error: cannot cast expression `dg` of type `int delegate()` to `int`
    { auto x = cast(int)dg; }   // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(371): Error: cannot cast expression `da` of type `int[]` to `int`
    { auto x = cast(int)da; }   // Reject (Bugzilla 11484)
                        ^
fail_compilation/fail_casting1.d(372): Error: cannot cast expression `sa` of type `int[1]` to `int`
    { auto x = cast(int)sa; }   // Reject (Bugzilla 11484)
                        ^
fail_compilation/fail_casting1.d(373): Error: cannot cast expression `aa` of type `int[int]` to `int`
    { auto x = cast(int)aa; }   // Reject (from e2ir)
                        ^
fail_compilation/fail_casting1.d(374): Error: cannot cast expression `c` of type `fail_casting1.C` to `int`
    { auto x = cast(int) c; }   // Reject (Bugzilla 7472)
                         ^
fail_compilation/fail_casting1.d(380): Error: cannot cast expression `0` of type `int` to `int[1]`
    { auto x = cast(SA) 0; }        // Reject (Bugzilla 14154)
                        ^
fail_compilation/fail_casting1.d(381): Error: cannot cast expression `0` of type `int` to `S`
    { auto x = cast( S) 0; }        // Reject (Bugzilla 14154)
                        ^
fail_compilation/fail_casting1.d(382): Error: cannot cast expression `i` of type `int` to `int[1]`
    { auto x = cast(SA) i; }        // Reject (Bugzilla 14154)
                        ^
fail_compilation/fail_casting1.d(383): Error: cannot cast expression `i` of type `int` to `S`
    { auto x = cast( S) i; }        // Reject (Bugzilla 14154)
                        ^
fail_compilation/fail_casting1.d(384): Error: cannot cast expression `f` of type `double` to `int[1]`
    { auto x = cast(SA) f; }        // Reject (Bugzilla 14154)
                        ^
fail_compilation/fail_casting1.d(385): Error: cannot cast expression `f` of type `double` to `S`
    { auto x = cast( S) f; }        // Reject (Bugzilla 14154)
                        ^
fail_compilation/fail_casting1.d(386): Error: cannot cast expression `sa` of type `int[1]` to `int`
    { auto x = cast(int)sa; }       // Reject (Bugzilla 14154)
                        ^
fail_compilation/fail_casting1.d(387): Error: cannot cast expression `s` of type `S` to `int`
    { auto x = cast(int) s; }       // Reject (Bugzilla 14154)
                         ^
fail_compilation/fail_casting1.d(388): Error: cannot cast expression `sa` of type `int[1]` to `double`
    { auto x = cast(double)sa; }    // Reject (Bugzilla 14154)
                           ^
fail_compilation/fail_casting1.d(389): Error: cannot cast expression `s` of type `S` to `double`
    { auto x = cast(double) s; }    // Reject (Bugzilla 14154)
                            ^
---
*/

void test1()
{
    { auto x = cast(SA) p; }        // Reject (Bugzilla 14596)
    { auto x = cast(SA)fp; }        // Reject (Bugzilla 14596) (FP is Tpointer)
    { auto x = cast(SA)dg; }        // Reject (from e2ir)
    { auto x = cast(SA)da; }        // Reject (from e2ir)
    { auto x = cast(SA)aa; }        // Reject (from e2ir)
    { auto x = cast(SA) c; }        // Reject (Bugzilla 10646)
    { auto x = cast(SA) n; }        // Reject (Bugzilla 8179)
    { auto x = cast( P)sa; }        // Accept (equivalent with: cast(int*)sa.ptr;)
    { auto x = cast(double*)sa; }   // Accept (equivalent with: cast(double*)sa.ptr;)
    { auto x = cast(FP)sa; }        // Accept (equivalent with: cast(FP)sa.ptr;)
    { auto x = cast(DG)sa; }        // Reject (from e2ir)
    { auto x = cast(DA)sa; }        // Accept (equivalent with: cast(int[])sa[];)
    { auto x = cast(double[])sa; }  // Reject (from e2ir)
    { auto x = cast(AA)sa; }        // Reject (from e2ir)
    { auto x = cast( C)sa; }        // Reject (Bugzilla 10646)
    { auto x = cast( N)sa; }        // Reject (Bugzilla 8179)
}

void test2()
{
    { auto x = cast( S) p; }        // Reject (Bugzilla 13959)
    { auto x = cast( S)fp; }        // Reject (Bugzilla 13959) (FP is Tpointer)
    { auto x = cast( S)dg; }        // Reject (from e2ir)
    { auto x = cast( S)da; }        // Reject (from e2ir)
    { auto x = cast( S)aa; }        // Reject (from e2ir)
    { auto x = cast( S) c; }        // Reject (from e2ir)
    { auto x = cast( S) n; }        // Reject (Bugzilla 9904)
    { auto x = cast( P) s; }        // Reject (Bugzilla 13959)
    { auto x = cast(FP) s; }        // Reject (Bugzilla 13959) (FP is Tpointer)
    { auto x = cast(DG) s; }        // Reject (from e2ir)
    { auto x = cast(DA) s; }        // Reject (from e2ir)
    { auto x = cast(AA) s; }        // Reject (from e2ir)
    { auto x = cast( C) s; }        // Reject (from e2ir)
    { auto x = cast( N) s; }        // Reject (Bugzilla 9904)
}

void test3()    // between reference types
{
    { auto x = cast( P) p; }    // Accept
    { auto x = cast(FP) p; }    // Accept (FP is Tpointer)
    { auto x = cast(DG) p; }    // Reject (from e2ir)
    { auto x = cast(DA) p; }    // Reject (Bugzilla 14596)
    { auto x = cast(AA) p; }    // Accept (because of size match)
    { auto x = cast( C) p; }    // Accept (because of size match)
    { auto x = cast( N) p; }    // Reject (Bugzilla 14629)

    { auto x = cast( P)fp; }    // Accept (FP is Tpointer)
    { auto x = cast(FP)fp; }    // Accept
    { auto x = cast(DG)fp; }    // Reject (from e2ir)
    { auto x = cast(DA)fp; }    // Reject (Bugzilla 14596)
    { auto x = cast(AA)fp; }    // Accept (because of size match)
    { auto x = cast( C)fp; }    // Accept (because of size match)
    { auto x = cast( N)fp; }    // Reject (Bugzilla 14629)

    { auto x = cast( P)dg; }    // Deprecated (equivalent with: cast( P)dg.ptr;)
    { auto x = cast(FP)dg; }    // Deprecated (equivalent with: cast(FP)dg.ptr;)
    { auto x = cast(DG)dg; }    // Accept
    { auto x = cast(DA)dg; }    // Reject (from e2ir)
    { auto x = cast(AA)dg; }    // Reject (from e2ir)
    { auto x = cast( C)dg; }    // Reject (from e2ir)
    { auto x = cast( N)dg; }    // Reject (Bugzilla 14629)

    { auto x = cast( P) n; }    // Accept
    { auto x = cast(FP) n; }    // Accept
    { auto x = cast(DG) n; }    // Accept
    { auto x = cast(DA) n; }    // Accept
    { auto x = cast(AA) n; }    // Accept
    { auto x = cast( C) n; }    // Accept
    { auto x = cast( N) n; }    // Accept

    { auto x = cast( P)da; }    // Accept (equivalent with: cast(P)da.ptr;)
    { auto x = cast(FP)da; }    // Accept (FP is Tpointer)
    { auto x = cast(DG)da; }    // Reject (from e2ir)
    { auto x = cast(DA)da; }    // Accept
    { auto x = cast(AA)da; }    // Reject (from e2ir)
    { auto x = cast( C)da; }    // Reject (Bugzilla 10646)
    { auto x = cast( N)da; }    // Reject (Bugzilla 14629)

    { auto x = cast( P)aa; }    // Accept (because of size match)
    { auto x = cast(FP)aa; }    // Accept (FP is Tpointer)
    { auto x = cast(DG)aa; }    // Reject (from e2ir)
    { auto x = cast(DA)aa; }    // Reject (from e2ir)
    { auto x = cast(AA)aa; }    // Accept
    { auto x = cast( C)aa; }    // Accept (because of size match)
    { auto x = cast( N)aa; }    // Reject (Bugzilla 14629)

    { auto x = cast( P) c; }    // Accept
    { auto x = cast(FP) c; }    // Accept (FP is Tpointer)
    { auto x = cast(DG) c; }    // Reject (from e2ir)
    { auto x = cast(DA) c; }    // Reject (Bugzilla 10646)
    { auto x = cast(AA) c; }    // Accept (because of size match)
    { auto x = cast( C) c; }    // Accept
    { auto x = cast( N) c; }    // Reject (Bugzilla 14629)
}

void test4()
{
    { auto x = cast( P) 0; }    // Accept
    { auto x = cast(FP) 0; }    // Accept
    { auto x = cast(DG) 0; }    // Reject (from constfold)
    { auto x = cast(DA) 0; }    // Reject (Bugzilla 11484)
    { auto x = cast(SA) 0; }    // Reject (Bugzilla 11484)
    { auto x = cast(AA) 0; }    // Reject (from constfold)
    { auto x = cast( C) 0; }    // Reject (Bugzilla 11485)
    { auto x = cast( N) 0; }    // Reject (from constfold)

    { auto x = cast( P) i; }    // Accept
    { auto x = cast(FP) i; }    // Accept
    { auto x = cast(DG) i; }    // Reject (from e2ir)
    { auto x = cast(DA) i; }    // Reject (Bugzilla 11484)
    { auto x = cast(SA) i; }    // Reject (Bugzilla 11484)
    { auto x = cast(AA) i; }    // Reject (from e2ir)
    { auto x = cast( C) i; }    // Reject (Bugzilla 11485)
    { auto x = cast( N) i; }    // Reject (from e2ir)

    { auto x = cast(int) p; }   // Accept
    { auto x = cast(int)fp; }   // Accept
    { auto x = cast(int)dg; }   // Reject (from e2ir)
    { auto x = cast(int)da; }   // Reject (Bugzilla 11484)
    { auto x = cast(int)sa; }   // Reject (Bugzilla 11484)
    { auto x = cast(int)aa; }   // Reject (from e2ir)
    { auto x = cast(int) c; }   // Reject (Bugzilla 7472)
    { auto x = cast(int) n; }   // Accept
}

void test5()
{
    { auto x = cast(SA) 0; }        // Reject (Bugzilla 14154)
    { auto x = cast( S) 0; }        // Reject (Bugzilla 14154)
    { auto x = cast(SA) i; }        // Reject (Bugzilla 14154)
    { auto x = cast( S) i; }        // Reject (Bugzilla 14154)
    { auto x = cast(SA) f; }        // Reject (Bugzilla 14154)
    { auto x = cast( S) f; }        // Reject (Bugzilla 14154)
    { auto x = cast(int)sa; }       // Reject (Bugzilla 14154)
    { auto x = cast(int) s; }       // Reject (Bugzilla 14154)
    { auto x = cast(double)sa; }    // Reject (Bugzilla 14154)
    { auto x = cast(double) s; }    // Reject (Bugzilla 14154)
}
