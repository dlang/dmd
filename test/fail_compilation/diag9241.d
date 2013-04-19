// REQUIRED_ARGS: -property
/*
TEST_OUTPUT:
---
fail_compilation/diag9241.d(18): Error: not a property s.splitLines
fail_compilation/diag9241.d(18): Error: cannot implicitly convert expression (splitLines(s)) of type string[] to string
---
*/

S[] splitLines(S)(S s)
{
    return null;
}

void main()
{
    string s;
    s = s.splitLines;
}
