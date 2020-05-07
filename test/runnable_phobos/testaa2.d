/*
PERMUTE_ARGS:
RUN_OUTPUT:
---
Success
---
*/

extern(C) int printf(const char*, ...);

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=3825

import std.math;    // necessary for ^^=
void test3825()
{
    // Check for RangeError is thrown
    bool thrown(T)(lazy T cond)
    {
        import core.exception;
        bool f = false;
        try {
            cond();
        } catch (RangeError e) { f = true; }
        return f;
    }

    int[int] aax;
    int[][int] aay;

    aax = null, aay = null;
    assert(thrown(aax[0]));
    assert(thrown(aax[0]   = aax[0]));  // rhs throws
    assert(thrown(aax[0]  += aax[0]));  // rhs throws
    assert(thrown(aax[0] ^^= aax[0]));  // rhs throws
    assert(thrown(aay[0]  ~= aay[0]));  // rhs throws
    aax = null;   aax[0]   = 1;  assert(aax[0] ==  1);  // setting aax[0] is OK
    aax = null;   aax[0]  += 1;  assert(aax[0] == +1);  // setting aax[0] to 0 and modify it is OK
    aax = null;   aax[0] ^^= 1;  assert(aax[0] ==  0);  // setting aax[0] to 0 and modify it is OK
    aay = null;   aay[0]  ~= []; assert(aay[0] == []);  // setting aay[0] to 0 and modify it is OK
    aax = null; ++aax[0];        assert(aax[0] == +1);  // setting aax[0] to 0 and modify it is OK
    aax = null; --aax[0];        assert(aax[0] == -1);  // setting aax[0] to 0 and modify it is OK

    aax = [0:0], aay = [0:null];
    assert(thrown(aax[aax[1]]   = 1));  // accessing aax[1] in key part throws
    assert(thrown(aax[aax[1]]  += 1));  // accessing aax[1] in key part throws
    assert(thrown(aax[aax[1]] ^^= 1));  // accessing aax[1] in key part throws
    assert(thrown(aay[aax[1]]  ~= [])); // accessing aax[1] in key part throws

    //assert(thrown(aax[(  aax[1], 0)] = 0));
    /* accessing aax[1] in key part, why doesn't throw?
     * Because, in aax[(aax[1], 0)], aax[1] is in lhs of comma expression, and is treated
     * it has no side effect. Then optimizer eliminate it completely, and
     * whole expression succeed to run in runtime. */
    int n = 0;
    assert(thrown(aax[((){ n=aax[1]; return 0;}())] = 0)); // accessing aax[1] in key part, throws OK

    // This works as expected.
    int[int][int] aaa;
    aaa[0][0] = 0;              assert(aaa[0][0] == 0); // setting aaa[0][0] is OK

    // real test cases
    void bug3825()
    {
        string[] words = ["how", "are", "you", "are"];

        int[string] aa1;
        foreach (w; words)
            aa1[w] = ((w in aa1) ? (aa1[w] + 1) : 2);
        //writeln(aa1); // Prints: [how:1,you:1,are:2]

        int[string] aa2;
        foreach (w; words)
            if (w in aa2)
                aa2[w]++;
            else
                aa2[w] = 2;
        //writeln(aa2); // Prints: [how:2,you:2,are:3]

        assert(aa1 == aa2);
        assert(aa1 == ["how":2, "you":2, "are":3]);
        assert(aa2 == ["how":2, "you":2, "are":3]);
    }
    void bug5021()
    {
        int func()
        {
            throw new Exception("It's an exception.");
        }

        int[string] arr;
        try
        {
            arr["hello"] = func();
        }
        catch(Exception e)
        {
        }
        assert(arr.length == 0);
    }
    void bug7914()
    {
        size_t[ubyte] aa;
        aa[0] = aa.length;
        assert(aa[0] == 0);
    }
    void bug8070()
    {
        Object[string] arr;

        class A
        {
            this()
            {
                // at this point:
                assert("x" !in arr);
            }
        }

        arr["x"] = new A();
    }
    bug3825();
    bug5021();
    bug7914();
    bug8070();
}

/************************************************/

int main()
{
    test3825();

    printf("Success\n");
    return 0;
}
