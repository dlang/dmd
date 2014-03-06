/*
TEST_OUTPUT:
---
fail_compilation/fail260.d(26): Error: template instance Static!(4u, 4u) Static!(4u, 4u) is nested in both Static and Static
fail_compilation/fail260.d(32): Error: template instance fail260.Static!(1, 4).Static.MultReturn!(Static!(1, 4), Static!(4, 1)) error instantiating
fail_compilation/fail260.d(45):        instantiated from here: opMultVectors!(Static!(4, 1))
fail_compilation/fail260.d(45): Error: template instance fail260.Static!(1, 4).Static.opMultVectors!(Static!(4, 1)) error instantiating
---
*/
// REQUIRED_ARGS: -d
struct Static(uint width2, uint height2)
{
    immutable width = width2;
    immutable height = height2;

    static Static opCall()
    {
        Static ret;
        return ret;
    }

    alias float E;

    template MultReturn(alias M1, alias M2)
    {
        alias Static!(M2.width, M1.height) MultReturn;
    }


    void opMultVectors(M2)(M2 b)
    {
        alias MultReturn!(Static, M2) ret_matrix;
    }

}

void test()
{
    alias Static!(4, 1) matrix_stat;
    static matrix_stat m4 = matrix_stat();

    alias Static!(1, 4) matrix_stat2;
    static m6 = matrix_stat2();

    m6.opMultVectors(m4);
}
