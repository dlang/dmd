// test to ensure accuracy of "^^" in ctfe is same as runtime pow()

bool checkPow(alias A, alias B)()
{
    import std.math : pow;
    enum ct = A ^^ B;
    return ct == pow(A, B);
}

void main()
{
    assert(checkPow!(1.75L, 1 / 3.0L)());
    assert(checkPow!(1 / 3.0L, 1.75L)());
    assert(checkPow!(3.75L, 2.33L)());
    assert(checkPow!(138.88L, 74.33L)());
    assert(checkPow!(138.88L, 0.22L)());
    assert(checkPow!(247.38L, 5.13L)());
}