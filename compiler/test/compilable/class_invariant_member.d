class C
{
    int x;
    invariant { assert(x >= 0); }
    invariant { assert(x < 100); }
}

class D : C { }

struct S
{
    int y;
    invariant { assert(y != 1); }
}

class N { }

static assert(__traits(hasMember, C, "__invariant"));
static assert(__traits(hasMember, S, "__invariant"));
static assert(!__traits(hasMember, N, "__invariant"));

static assert(__traits(isSame, __traits(parent, C.__invariant), C));
static assert(__traits(isSame, __traits(parent, D.__invariant), C));

static assert(__traits(compiles, &C.__invariant));

bool listed(T)()
{
    foreach (m; __traits(allMembers, T))
        if (m == "__invariant")
            return true;
    return false;
}
static assert(listed!C);
static assert(listed!S);
static assert(!listed!N);
