
template Unqual(T)
{
		 static if (is(T U == shared(const U))) alias U Unqual;
	else static if (is(T U ==        const U )) alias U Unqual;
	else static if (is(T U ==    immutable U )) alias U Unqual;
	else static if (is(T U ==       shared U )) alias U Unqual;
	else                                        alias T Unqual;
}

static assert(is(Unqual!(const(Object)) == const(Object)ref));
static assert(is(Unqual!(const(Object ref)) == const(Object)ref));
static assert(is(Unqual!(const(immutable(Object)ref)) == immutable(Object)ref));
static assert(!is(Unqual!(const(Object)) == const(Object)));
static assert(!is(Unqual!(const(Object)) == Object));
