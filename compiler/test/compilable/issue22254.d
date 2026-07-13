// https://github.com/dlang/dmd/issues/22254

void main()
{
    assert(assert(0, ""), "");
}
