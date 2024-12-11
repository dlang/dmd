/*
TEST_OUTPUT:
---
fail_compilation/ice12850.d(14): Error: cannot implicitly convert expression `0` of type `int` to `string`
    alias staticZip = TypeTuple!(arr[0]);
                                     ^
---
*/
alias TypeTuple(TL...) = TL;

void main()
{
    int[string] arr;
    alias staticZip = TypeTuple!(arr[0]);
}
