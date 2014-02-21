// PERMUTE_ARGS:
// EXTRA_SOURCES: imports/mangle10077.d

/***************************************************/
// 10077 - pragma(mangle)

pragma(mangle, "_test10077a_") int test10077a;
static assert(test10077a.mangleof == "_test10077a_");

__gshared pragma(mangle, "_test10077b_") ubyte test10077b;
static assert(test10077b.mangleof == "_test10077b_");

pragma(mangle, "_test10077c_") void test10077c() {}
static assert(test10077c.mangleof == "_test10077c_");

pragma(mangle, "_test10077f_") __gshared char test10077f;
static assert(test10077f.mangleof == "_test10077f_");

pragma(mangle, "_test10077g_") @system { void test10077g() {} }
static assert(test10077g.mangleof == "_test10077g_");

template getModuleInfo(alias mod)
{
    pragma(mangle, "_D"~mod.mangleof~"12__ModuleInfoZ") static __gshared extern ModuleInfo mi;
    enum getModuleInfo = &mi;
}

void test10077h()
{
    assert(getModuleInfo!(object).name == "object");
}

//UTF-8 chars
__gshared extern pragma(mangle, "test_эльфийские_письмена_9") ubyte test10077i_evar;

void test10077i()
{
    import imports.mangle10077;

    setTest10077i();
    assert(test10077i_evar == 42);
}

/***************************************************/

void main()
{
    test10077h();
    test10077i();
}
