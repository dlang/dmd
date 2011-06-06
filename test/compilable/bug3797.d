
ref int frvv();

void main()
{
    // Cannot convert if the return type or parameters are different

    void function() vv;
    void function(int) vi;
    int function() iv;
    const(int) function() cv;

    static assert( is(typeof( vv = vv )));
    static assert(!is(typeof( vv = vi )));
    static assert(!is(typeof( vv = iv )));
    static assert(!is(typeof( vv = cv )));

    static assert(!is(typeof( vi = vv )));
    static assert( is(typeof( vi = vi )));
    static assert(!is(typeof( vi = iv )));
    static assert(!is(typeof( vi = cv )));

    static assert(!is(typeof( iv = vv )));
    static assert(!is(typeof( iv = vi )));
    static assert( is(typeof( iv = iv )));
    static assert(!is(typeof( iv = cv )));

    static assert(!is(typeof( cv = vv )));
    static assert(!is(typeof( cv = iv )));
    static assert(!is(typeof( cv = vi )));
    static assert( is(typeof( cv = cv )));

    // functions with different linkages can't convert

    extern(C) void function() cfunc;
    extern(D) void function() dfunc;

    static assert(!is(typeof( cfunc = dfunc )));
    static assert(!is(typeof( dfunc = cfunc )));

    // ref return can't convert to non-ref return

    typeof(&frvv) rvv;

    static assert(!is(typeof( rvv = iv )));
    static assert(!is(typeof( rvv = cv )));

    static assert(!is(typeof( iv = rvv )));
    static assert(!is(typeof( cv = rvv )));

    // variadic functions don't mix

    void function(...) vf;

    static assert(!is(typeof( vf = vv )));
    static assert(!is(typeof( vv = vf )));

    // non-nothrow -> nothrow

    void function() nothrow ntf;

    static assert(!is(typeof( ntf = vv )));
    static assert( is(typeof( vv = ntf )));

    // @safe -> @trusted -> @system

    void function() @system systemfunc;
    void function() @trusted trustedfunc;
    void function() @safe safefunc;

    static assert( is(typeof( trustedfunc = safefunc )));
    static assert( is(typeof( systemfunc = trustedfunc )));
    static assert( is(typeof( systemfunc = safefunc )));

    static assert(!is(typeof( safefunc = trustedfunc )));
    static assert(!is(typeof( trustedfunc = systemfunc )));
    static assert(!is(typeof( safefunc = systemfunc )));

    // pure -> non-pure

    void function() nonpurefunc;
    void function() pure purefunc;

    static assert(!is(typeof( purefunc = nonpurefunc )));
    static assert( is(typeof( nonpurefunc = purefunc )));

    // Cannot convert parameter storage classes (except const to in and in to const)

    void function(const(int)) constfunc;
    void function(in int) infunc;
    void function(out int) outfunc;
    void function(ref int) reffunc;
    void function(lazy int) lazyfunc;

    static assert(is(typeof( infunc = constfunc )));
    static assert(is(typeof( constfunc = infunc )));

    static assert(!is(typeof( infunc = outfunc )));
    static assert(!is(typeof( infunc = reffunc )));
    static assert(!is(typeof( infunc = lazyfunc )));

    static assert(!is(typeof( outfunc = infunc )));
    static assert(!is(typeof( outfunc = reffunc )));
    static assert(!is(typeof( outfunc = lazyfunc )));

    static assert(!is(typeof( reffunc = infunc )));
    static assert(!is(typeof( reffunc = outfunc )));
    static assert(!is(typeof( reffunc = lazyfunc )));

    static assert(!is(typeof( lazyfunc = infunc )));
    static assert(!is(typeof( lazyfunc = outfunc )));
    static assert(!is(typeof( lazyfunc = reffunc )));

    // Test all the conversions at once
    void function(in const(int)) @safe pure nothrow restrictedfunc;
    void function(in int) relaxedfunc = restrictedfunc;
}
