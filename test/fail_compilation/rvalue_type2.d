/* REQUIRED_ARGS: -preview=rvaluetype
TEST_OUTPUT:
---
fail_compilation/rvalue_type2.d(17): Error: cannot return lvalue as `@rvalue`, perhaps you meant `cast(@rvalue)p`
fail_compilation/rvalue_type2.d(22): Error: returning `f0(a)` escapes a reference to local variable `a`
fail_compilation/rvalue_type2.d(23): Error: returning `f0(((@rvalue @rvalue(int) __rvalue2 = 1;) , __rvalue2))` escapes a reference to local variable `__rvalue2`
fail_compilation/rvalue_type2.d(24): Error: returning `f1(a)` escapes a reference to local variable `a`
fail_compilation/rvalue_type2.d(25): Error: returning `f2(a)` escapes a reference to local variable `a`
fail_compilation/rvalue_type2.d(26): Error: returning `f2(((@rvalue @rvalue(int) __rvalue3 = 2;) , __rvalue3))` escapes a reference to local variable `__rvalue3`
fail_compilation/rvalue_type2.d(30): Error: returning `a` escapes a reference to local variable `a`
---
*/

ref escape()
{
    static ref int f0(@rvalue ref int p) { return p; }
    static ref @rvalue(int) f1(ref int p) { return p; }
    static ref @rvalue(int) f2(@rvalue ref int p) { return p; }
    int a;
    switch(a)
    {
    case 0: return f0(cast(@rvalue)a);
            return f0(1);
    case 1: return f1(a);
    case 2: return f2(cast(@rvalue)a);
            return f2(2);

    default: break;
    }
    return a;
}
