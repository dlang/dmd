/*
TEST_OUTPUT:
---
fail_compilation/ice9254c.d(27): Error: using the result of a comma expression is not allowed
    foreach(divisor; !(2, 3, 4, 8, 7, 9))
                       ^
fail_compilation/ice9254c.d(27): Error: using the result of a comma expression is not allowed
    foreach(divisor; !(2, 3, 4, 8, 7, 9))
                           ^
fail_compilation/ice9254c.d(27): Error: using the result of a comma expression is not allowed
    foreach(divisor; !(2, 3, 4, 8, 7, 9))
                              ^
fail_compilation/ice9254c.d(27): Error: using the result of a comma expression is not allowed
    foreach(divisor; !(2, 3, 4, 8, 7, 9))
                                 ^
fail_compilation/ice9254c.d(27): Error: using the result of a comma expression is not allowed
    foreach(divisor; !(2, 3, 4, 8, 7, 9))
                                    ^
fail_compilation/ice9254c.d(27): Error: invalid `foreach` aggregate `false` of type `bool`
    foreach(divisor; !(2, 3, 4, 8, 7, 9))
    ^
---
*/

void main()
{
    foreach(divisor; !(2, 3, 4, 8, 7, 9))
    {
        assert(0);

        // ice in ForeachRangeStatement::comeFrom()
        foreach (v; 0..uint.max) {}

        // ice in WhileStatement::comeFrom()
        while (1) {}
    }
}
