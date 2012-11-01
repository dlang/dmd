module test1673;

template is_Type_Spec(alias T)
{
    enum bool is_Type_Spec = is(T == template);
}

template is_Type_Ident_Spec(alias T)
{
    static if (is(T x == template))
    {
        static assert(is_Type_Spec!x);
        enum bool is_Type_Ident_Spec = true;
    }
    else
    {
        enum bool is_Type_Ident_Spec = false;
    }
}

template Foo(T...) { }

template Bar(T...)
{
    template Doo(T...)
    {
    }
}

template TypeTuple(T...) { alias T TypeTuple; }

void main()
{
    static assert(is_Type_Spec!Foo);
    static assert(is_Type_Ident_Spec!Foo);
    static assert(!is_Type_Spec!(Foo!int));
    static assert(!is_Type_Ident_Spec!(Foo!int));
    static assert(!is_Type_Spec!main);
    static assert(!is_Type_Ident_Spec!main);
    
    static assert(is(Bar == template));
    static assert(!is(Bar!int == template));
    static assert(is(Bar!(int).Doo == template));
    static assert(!is(Bar!(int).Doo!int == template));
    
    alias TypeTuple!(Foo, Foo!int, Bar, Bar!int, Bar!(int).Doo, Bar!(int).Doo!int) X;
    
    static assert(is(X[0] == template));
    static assert(!is(X[1] == template));
    static assert(is(X[2] == template));
    static assert(!is(X[3] == template));
    static assert(is(X[4] == template));
    static assert(!is(X[5] == template));
}
