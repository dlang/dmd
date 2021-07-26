module unique_typeinfo_names;

// https://issues.dlang.org/show_bug.cgi?id=22149
void structs()
{
    static struct Foo(T) {}

    auto foo()
    {
        struct S {}
        return Foo!S();
    }

    auto bar()
    {
        struct S {}
        return Foo!S();
    }

    auto f = foo();
    auto b = bar();

    assert(typeid(f) != typeid(b));
    assert(typeid(f).name != typeid(b).name);

    assert(typeid(f).mangledName == typeof(f).mangleof);
    assert(typeid(b).mangledName == typeof(b).mangleof);
    assert(typeid(f).name == "unique_typeinfo_names.structs().Foo!(unique_typeinfo_names.structs().foo().S).Foo");
    assert(typeid(b).name == "unique_typeinfo_names.structs().Foo!(unique_typeinfo_names.structs().bar().S).Foo");
}

void main()
{
    structs();
}
