/*
TEST_OUTPUT:
---
fail_compilation/fail18620.d(14): Error: `strlen` cannot be interpreted at compile time, because it has no available source code
fail_compilation/fail18620.d(19):        compile time context created here: `static A a = new A("a");`
fail_compilation/fail18620.d(14): Error: `strlen` cannot be interpreted at compile time, because it has no available source code
fail_compilation/fail18620.d(20):        compile time context created here: `__gshared A b = new A("b");`
---
*/
class A{
    this(const(char)* s)
    {
        import core.stdc.string;
        auto a=strlen(s);
    }
}

void main(){
    static a = new A("a");
    __gshared b = new A("b");
}
