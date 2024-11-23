/*
TEST_OUTPUT:
----
fail_compilation/ice12727.d(26): Error: template instance `IndexTuple!(1, 0)` recursive template expansion
        alias IndexTuple = IndexTuple!(e);
                           ^
fail_compilation/ice12727.d(26): Error: alias `ice12727.IndexTuple!(1, 0).IndexTuple` recursive alias declaration
        alias IndexTuple = IndexTuple!(e);
        ^
fail_compilation/ice12727.d(33): Error: template instance `ice12727.IndexTuple!(1, 0)` error instantiating
        foreach (j; IndexTuple!(1)) {}
                    ^
fail_compilation/ice12727.d(37):        instantiated from here: `Matrix!(float, 3)`
alias Vector(T, int M) = Matrix!(T, M);
                         ^
fail_compilation/ice12727.d(38):        instantiated from here: `Vector!(float, 3)`
alias Vector3 = Vector!(float, 3);
                ^
----
*/
template IndexTuple(int e, int s = 0, T...)
{
    static if (s == e)
        alias IndexTuple = T;
    else
        alias IndexTuple = IndexTuple!(e);
}

struct Matrix(T, int N = M)
{
    pure decomposeLUP()
    {
        foreach (j; IndexTuple!(1)) {}
    }
}

alias Vector(T, int M) = Matrix!(T, M);
alias Vector3 = Vector!(float, 3);
