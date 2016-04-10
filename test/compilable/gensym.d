// PERMUTE_ARGS:
// REQUIRED_ARGS: -o-

/***************************************************/
// 12100


struct S12100 {
    static string foo(string sym = __GENSYM__)() {
        return sym;
    }
    static string foo(string sym = __GENSYM__)(int n) {
        return sym;
    }
    static string bar(string sym = __GENSYM__) {
        return sym;
    }
    static string bar(int n, string sym = __GENSYM__) {
        return sym;
    }
    
    static int baz(int n = __LINE__) {
        return n;
    }
    enum gensym = __GENSYM__;
}
class C12100 {
    static string foo(string sym = __GENSYM__)() {
        return sym;
    }
    static string foo(string sym = __GENSYM__)(int n) {
        return sym;
    }
    static string bar(string sym = __GENSYM__) {
        return sym;
    }
    static string bar(int n, string sym = __GENSYM__) {
        return sym;
    }
    
    static int baz(int n = __LINE__) {
        return n;
    }
    enum gensym = __GENSYM__;
}

enum gs1 = __GENSYM__;
enum gs2 = __GENSYM__;

void test12100()
{
    static assert(gs1 != gs2);
    static assert(S12100.gensym == S12100.gensym);
    static assert(S12100.foo() != S12100.foo(3));
    static assert(S12100.bar() != S12100.bar());
    static assert(S12100.bar() != S12100.bar(3));
    static assert(S12100.gensym != C12100.gensym);
    static assert(C12100.gensym == C12100.gensym);
    static assert(C12100.foo() != C12100.foo(3));
    static assert(C12100.bar() != C12100.bar());
    static assert(C12100.bar() != C12100.bar(3));
    static assert(__GENSYM__ != __GENSYM__);
    mixin("enum a = __GENSYM__;");
    mixin("enum b = __GENSYM__;");
    static assert(a != b);
    
    enum c = S12100.baz();
    enum d = S12100.baz();
    static assert(c != d);
}