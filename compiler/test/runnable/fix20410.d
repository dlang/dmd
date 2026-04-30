/*
REQUIRED_ARGS: runnable/imports/imp20410.c
*/
//https://github.com/dlang/dmd/issues/20410
import imp20410;

void main()
{
    const _ = _RAX;

    assert(num == 5);
    assert(func() == 9);

    //https://github.com/dlang/dmd/issues/20478

    static assert(A == B);
    static assert(A == C);
    static assert(A == D);
}
