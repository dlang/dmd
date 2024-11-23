/*
TEST_OUTPUT:
---
fail_compilation/ice9254b.d(29): Error: using the result of a comma expression is not allowed
        foreach(divisor; !(2, 3, 4, 8, 7, 9))
                           ^
fail_compilation/ice9254b.d(29): Error: using the result of a comma expression is not allowed
        foreach(divisor; !(2, 3, 4, 8, 7, 9))
                               ^
fail_compilation/ice9254b.d(29): Error: using the result of a comma expression is not allowed
        foreach(divisor; !(2, 3, 4, 8, 7, 9))
                                  ^
fail_compilation/ice9254b.d(29): Error: using the result of a comma expression is not allowed
        foreach(divisor; !(2, 3, 4, 8, 7, 9))
                                     ^
fail_compilation/ice9254b.d(29): Error: using the result of a comma expression is not allowed
        foreach(divisor; !(2, 3, 4, 8, 7, 9))
                                        ^
fail_compilation/ice9254b.d(29): Error: invalid `foreach` aggregate `false` of type `bool`
        foreach(divisor; !(2, 3, 4, 8, 7, 9))
        ^
---
*/

class C
{
    synchronized void foo()
    {
        foreach(divisor; !(2, 3, 4, 8, 7, 9))
        {
            // ice in ForeachRangeStatement::usesEH()
            foreach (v; 0..uint.max) {}

            // ice in WhileStatement::usesEH()
            while (1) {}
        }
    }
}
