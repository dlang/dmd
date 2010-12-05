template Unqual(T)
{
    version (none) // Error: recursive alias declaration @@@BUG1308@@@
    {
             static if (is(T U ==     const U)) alias Unqual!U Unqual;
        else static if (is(T U == immutable U)) alias Unqual!U Unqual;
        else static if (is(T U ==    shared U)) alias Unqual!U Unqual;
        else                                    alias        T Unqual;
    }
    else // workaround
    {
             static if (is(T U == shared(const U))) alias U Unqual;
        else static if (is(T U ==        const U )) alias U Unqual;
        else static if (is(T U ==    immutable U )) alias U Unqual;
        else static if (is(T U ==       shared U )) alias U Unqual;
        else                                        alias T Unqual;
    }
}

//unittest
//{
//    static assert(is(Unqual!(int) == int));
//    static assert(is(Unqual!(const int) == int));
//    static assert(is(Unqual!(immutable int) == int));
//    static assert(is(Unqual!(shared int) == int));
//    static assert(is(Unqual!(shared(const int)) == int));
//    alias immutable(int[]) ImmIntArr;
//    static assert(is(Unqual!(ImmIntArr) == immutable(int)[]));
	
    static assert(is(Unqual!(const(Object)) == const(Object)ref));
    static assert(is(Unqual!(const(Object ref)) == const(Object)ref));
    static assert(is(Unqual!(const(immutable(Object)ref)) == immutable(Object)ref));
    static assert(!is(Unqual!(const(Object)) == const(Object)));
    static assert(!is(Unqual!(const(Object)) == Object));
//}

import std.stdio;

alias const(Object)ref OO;

void test(const(OO)ref o) {}

int main()
{
	writeln((&test).mangleof);

	writeln((const(Object)ref).stringof);
	writeln((immutable(Object)ref).stringof);
	writeln((shared(Object)ref).stringof);
	writeln((const(Object)ref).mangleof);
	writeln((immutable(Object)ref).mangleof);
	writeln((shared(Object)ref).mangleof);
	writeln(Object.mangleof);
	assert((const(Object)ref).stringof == "const(Object)ref");
	assert((immutable(Object)ref).stringof == "immutable(Object)ref");
	assert((shared(Object)ref).stringof == "shared(Object)ref");
	assert((const(Object)).stringof == "const(Object)");
	assert((immutable(Object)).stringof == "immutable(Object)");
	assert((shared(Object)).stringof == "shared(Object)");
//	writeln((immutable(Object)ref).mangleof ~ " hello");
	//writeln((shared(const(Object)ref)).stringof);
	//writeln((shared(const(Object)ref[])*).stringof);
	//assert((shared(const(Object)ref)).stringof == "shared(const(Object)ref)");
	//assert((shared(const(Object)ref[])*).stringof == "shared(const(Object)ref[])*");
	return 0;
}
