// PERMUTE_ARGS:

// ICE(todt.c) DMD 2.053
// Bugzilla 6235

struct S
{
    alias typeof(string.init[$]) Elem;
}

struct S2(R)
{
    alias typeof(R.init[$]) Elem;
}

void main()
{
    S s;
    S2!string s2;
}
