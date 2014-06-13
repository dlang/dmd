/*
TEST_OUTPUT:
---
fail_compilation/ice10486.d(11): Error: cannot implicitly convert expression (null_) of type typeof(null) to int[1]
---
*/

void main()
{
    typeof(null) null_;
    int[1] sarr = null_;
}
