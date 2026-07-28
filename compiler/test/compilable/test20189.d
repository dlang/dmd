// https://github.com/dlang/dmd/issues/20189
// Deeper recursive assertions fail to compile

void main()
{
    assert(assert(0, "hello"), "hello again");
    assert(assert(assert(0, "hello once again"), "hello"), "hello again");
    assert(assert(assert(assert(0))));
}
