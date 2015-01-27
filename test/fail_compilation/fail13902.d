// REQUIRED_ARGS: -o-

struct S1 { int v; }
struct S2 { int* p; }
class C { int v; }

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(32): Error: escaping reference to local x
fail_compilation/fail13902.d(33): Error: escaping reference to local variable s1
fail_compilation/fail13902.d(38): Error: escaping reference to local sa1
fail_compilation/fail13902.d(39): Error: escaping reference to local variable sa2
fail_compilation/fail13902.d(40): Error: escaping reference to local x
fail_compilation/fail13902.d(41): Error: escaping reference to local x
fail_compilation/fail13902.d(42): Error: escaping reference to local x
fail_compilation/fail13902.d(45): Error: escaping reference to local y
---
*/
int* testEscape1()
{
    int x, y;
    int[] da1;
    int[][] da2;
    int[1] sa1;
    int[1][1] sa2;
    int* ptr;
    S1 s1;
    S2 s2;
    C  c;

    if (0) return &x;               // VarExp
    if (0) return &s1.v;            // DotVarExp
    if (0) return s2.p;             // no error
    if (0) return &c.v;             // no error
    if (0) return &da1[0];          // no error
    if (0) return &da2[0][0];       // no error
    if (0) return &sa1[0];          // IndexExp
    if (0) return &sa2[0][0];       // IndexExp
    if (0) return ptr = &x;
    if (0) return ptr = &x + 1;     // optimized to SymOffExp == (& x+4)
    if (0) return ptr = &x + x;
  //if (0) return ptr += &x + 1;    // semantic error
    if (0) return ptr -= &x - &y;   // no error
    if (0) return (&x, &y);         // CommaExp

    return null;    // ok
}

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(75): Error: escaping reference to local x
fail_compilation/fail13902.d(76): Error: escaping reference to local variable s1
fail_compilation/fail13902.d(81): Error: escaping reference to local sa1
fail_compilation/fail13902.d(82): Error: escaping reference to local variable sa2
fail_compilation/fail13902.d(83): Error: escaping reference to local x
fail_compilation/fail13902.d(84): Error: escaping reference to local x
fail_compilation/fail13902.d(85): Error: escaping reference to local x
fail_compilation/fail13902.d(88): Error: escaping reference to local y
---
*/
int* testEscape2(
    int x, int y,
    int[] da1,
    int[][] da2,
    int[1] sa1,
    int[1][1] sa2,
    int* ptr,
    S1 s1,
    S2 s2,
    C  c,
)
{
    if (0) return &x;               // VarExp
    if (0) return &s1.v;            // DotVarExp
    if (0) return s2.p;             // no error
    if (0) return &c.v;             // no error
    if (0) return &da1[0];          // no error
    if (0) return &da2[0][0];       // no error
    if (0) return &sa1[0];          // IndexExp
    if (0) return &sa2[0][0];       // IndexExp
    if (0) return ptr = &x;
    if (0) return ptr = &x + 1;     // optimized to SymOffExp == (& x+4)
    if (0) return ptr = &x + x;
  //if (0) return ptr += &x + 1;    // semantic error
    if (0) return ptr -= &x - &y;   // no error
    if (0) return (&x, &y);         // CommaExp

    return null;    // ok
}

/*
TEST_OUTPUT:
---
---
*/
int* testEscape3(
    ref int x, ref int y,
    ref int[] da1,
    ref int[][] da2,
    ref int[1] sa1,
    ref int[1][1] sa2,
    ref int* ptr,
    ref S1 s1,
    ref S2 s2,
    ref C  c,
)
{
    if (0) return &x;               // VarExp
    if (0) return &s1.v;            // DotVarExp
    if (0) return s2.p;             // no error
    if (0) return &c.v;             // no error
    if (0) return &da1[0];          // no error
    if (0) return &da2[0][0];       // no error
    if (0) return &sa1[0];          // IndexExp
    if (0) return &sa2[0][0];       // IndexExp
    if (0) return ptr = &x;
    if (0) return ptr = &x + 1;     // optimized to SymOffExp == (& x+4)
    if (0) return ptr = &x + x;
  //if (0) return ptr += &x + 1;    // semantic error
    if (0) return ptr -= &x - &y;   // no error
    if (0) return (&x, &y);         // CommaExp

    return null;    // ok
}

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(151): Error: escaping reference to local variable x
fail_compilation/fail13902.d(152): Error: escaping reference to local variable s1
fail_compilation/fail13902.d(156): Error: escaping reference to local variable sa1
fail_compilation/fail13902.d(157): Error: escaping reference to local variable sa2
fail_compilation/fail13902.d(158): Error: escaping reference to local variable x
fail_compilation/fail13902.d(159): Error: escaping reference to local variable x
fail_compilation/fail13902.d(160): Error: escaping reference to local variable s1
fail_compilation/fail13902.d(161): Error: escaping reference to local variable s1
---
*/
ref int testEscapeRef1()
{
    int x;
    int[] da1;
    int[][] da2;
    int[1] sa1;
    int[1][1] sa2;
    S1 s1;
    C  c;

    if (0) return x;            // VarExp
    if (0) return s1.v;         // DotVarExp
    if (0) return c.v;          // no error
    if (0) return da1[0];       // no error
    if (0) return da2[0][0];    // no error
    if (0) return sa1[0];       // IndexExp
    if (0) return sa2[0][0];    // IndexExp
    if (0) return x = 1;        // AssignExp
    if (0) return x += 1;       // BinAssignExp
    if (0) return s1.v = 1;     // AssignExp (e1 is DotVarExp)
    if (0) return s1.v += 1;    // BinAssignExp (e1 is DotVarExp)

    static int g;
    return g;       // ok
}

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(190): Error: escaping reference to local variable x
fail_compilation/fail13902.d(191): Error: escaping reference to local variable s1
fail_compilation/fail13902.d(195): Error: escaping reference to local variable sa1
fail_compilation/fail13902.d(196): Error: escaping reference to local variable sa2
fail_compilation/fail13902.d(197): Error: escaping reference to local variable x
fail_compilation/fail13902.d(198): Error: escaping reference to local variable x
fail_compilation/fail13902.d(199): Error: escaping reference to local variable s1
fail_compilation/fail13902.d(200): Error: escaping reference to local variable s1
---
*/
ref int testEscapeRef2(
    int x,
    int[] da1,
    int[][] da2,
    int[1] sa1,
    int[1][1] sa2,
    S1 s1,
    C  c,
)
{
    if (0) return x;            // VarExp
    if (0) return s1.v;         // DotVarExp
    if (0) return c.v;          // no error
    if (0) return da1[0];       // no error
    if (0) return da2[0][0];    // no error
    if (0) return sa1[0];       // IndexExp
    if (0) return sa2[0][0];    // IndexExp
    if (0) return x = 1;        // AssignExp
    if (0) return x += 1;       // BinAssignExp
    if (0) return s1.v = 1;     // AssignExp (e1 is DotVarExp)
    if (0) return s1.v += 1;    // BinAssignExp (e1 is DotVarExp)

    static int g;
    return g;       // ok
}

/*
TEST_OUTPUT:
---
---
*/
ref int testEscapeRef2(
    ref int x,
    ref int[] da1,
    ref int[][] da2,
    ref int[1] sa1,
    ref int[1][1] sa2,
    ref S1 s1,
    ref C  c,
)
{
    if (0) return x;            // VarExp
    if (0) return s1.v;         // DotVarExp
    if (0) return c.v;          // no error
    if (0) return da1[0];       // no error
    if (0) return da2[0][0];    // no error
    if (0) return sa1[0];       // IndexExp
    if (0) return sa2[0][0];    // IndexExp
    if (0) return x = 1;        // AssignExp
    if (0) return x += 1;       // BinAssignExp
    if (0) return s1.v = 1;     // AssignExp (e1 is DotVarExp)
    if (0) return s1.v += 1;    // BinAssignExp (e1 is DotVarExp)

    static int g;
    return g;       // ok
}

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(244): Error: escaping reference to local x
fail_compilation/fail13902.d(245): Error: escaping reference to local x
---
*/
int*[]  testArrayLiteral1() { int x; return [&x]; }
int*[1] testArrayLiteral2() { int x; return [&x]; }

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(254): Error: escaping reference to local x
fail_compilation/fail13902.d(255): Error: escaping reference to local x
---
*/
S2  testStructLiteral1() { int x; return     S2(&x); }
S2* testStructLiteral2() { int x; return new S2(&x); }

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(264): Error: escaping reference to local variable sa
fail_compilation/fail13902.d(265): Error: escaping reference to local variable sa
---
*/
int[] testSlice1() { int[3] sa; return sa[]; }
int[] testSlice2() { int[3] sa; int n; return sa[n..2][1..2]; }

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(274): Error: escaping reference to the payload of variadic parameter vda
fail_compilation/fail13902.d(275): Error: escaping reference to the payload of variadic parameter vda
---
*/
ref int testDynamicArrayVariadic1(int[] vda...) { return vda[0]; }
int[]   testDynamicArrayVariadic2(int[] vda...) { return vda[]; }
int[3]  testDynamicArrayVariadic3(int[] vda...) { return vda[0..3]; }   // no error

/*
TEST_OUTPUT:
---
fail_compilation/fail13902.d(285): Error: escaping reference to the payload of variadic parameter vsa
fail_compilation/fail13902.d(286): Error: escaping reference to the payload of variadic parameter vsa
---
*/
ref int testStaticArrayVariadic1(int[3] vsa...) { return vsa[0]; }
int[]   testStaticArrayVariadic2(int[3] vsa...) { return vsa[]; }
int[3]  testStaticArrayVariadic3(int[3] vsa...) { return vsa[0..3]; }   // no error
