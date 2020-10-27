template ScopeClass(C)
if (is(C == class) && __traits(getLinkage, C) == "C++")
{
    
    extern(C++, class)
    extern(C++, __traits(getCppNamespaces,C))
    extern(C++, (ns))
    class ScopeClass { }
}
extern(C++) class Foo {}
extern(C++) void test(ScopeClass!Foo)
{
}
version(Posix)
{
    static assert (test.mangleof == "_Z4testP10ScopeClassIP3FooE");
}
else version (CppRuntimeMicrosoft)
{
    static assert (test.mangleof == "?test@@YAXPEAV?$ScopeClass@PEAVFoo@@@@@Z");
}
alias AliasSeq(T...) = T;
alias ns = AliasSeq!();
immutable ns2 = AliasSeq!();
extern(C++,(ns)) class Bar {}
extern(C++,) class Baz {}
extern(C++, (ns2)) class Quux {} 
