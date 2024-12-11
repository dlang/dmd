/*
TEST_OUTPUT:
---
fail_compilation/fail18620.d(22): Error: `strlen` cannot be interpreted at compile time, because it has no available source code
        auto a=strlen(s);
                     ^
fail_compilation/fail18620.d(27):        compile time context created here
    static a = new A("a");
           ^
fail_compilation/fail18620.d(22): Error: `strlen` cannot be interpreted at compile time, because it has no available source code
        auto a=strlen(s);
                     ^
fail_compilation/fail18620.d(28):        compile time context created here
    __gshared b = new A("b");
              ^
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
