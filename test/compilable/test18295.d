// REQUIRED_ARGS: -dip1000

// https://issues.dlang.org/show_bug.cgi?id=18295

// See test/fail_compilation/test18295.d for the non-`-dip1000` version`

scope class C { int i; }    // Notice the use of `scope` here

C increment(scope return C c) @safe  // Prior to the fix for 18295 an error would be emitted here
{                                    // which is too conservative
    c.i++;
    return c;
}

void main() @safe
{
    scope C c = new C();
    c.increment();
}
