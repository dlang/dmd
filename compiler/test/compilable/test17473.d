// https://github.com/dlang/dmd/issues/17473
// REQUIRED_ARGS: -profile=gc

inout(char)[] foo(inout(char)[] s) pure @safe
{
    s = s[0..1] ~ '%';
    return s;
}
