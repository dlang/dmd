// PERMUTE_ARGS:

class C
{
   int opApply(int delegate(ref int v) dg) { return 0; }
   int opApply(int delegate(ref int v) dg) const { return 0; }
   int opApply(int delegate(ref int v) dg) immutable { return 0; }
   int opApply(int delegate(ref int v) dg) shared { return 0; }
   int opApply(int delegate(ref int v) dg) shared const { return 0; }
}

class D
{
   int opApply(int delegate(ref int v) dg) const { return 0; }
}

class E
{
   int opApply(int delegate(ref int v) dg) shared const { return 0; }
}

template canForeach(T)
{
    enum canForeach = __traits(compiles, { foreach(a; new T) {} } );
}

void main()
{
    static assert(canForeach!C);
    static assert(canForeach!(const(C)));
    static assert(canForeach!(immutable(C)));
    static assert(canForeach!(shared(C)));
    static assert(canForeach!(shared(const(C))));

    static assert(canForeach!D);
    static assert(canForeach!(const(D)));
    static assert(canForeach!(immutable(D)));
    static assert(!canForeach!(shared(D)));
    static assert(!canForeach!(shared(const(D))));

    static assert(!canForeach!E);
    static assert(!canForeach!(const(E)));
    static assert(canForeach!(immutable(E)));
    static assert(canForeach!(shared(E)));
    static assert(canForeach!(shared(const(E))));
}
