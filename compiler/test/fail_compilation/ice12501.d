/*
TEST_OUTPUT:
----
fail_compilation/ice12501.d(43): Error: function `foo` is not callable using argument types `(int, int)`
                result[i] = fun[i](result[i], r[0]);
                                  ^
fail_compilation/ice12501.d(43):        expected 1 argument(s), not 2
fail_compilation/ice12501.d(50):        `ice12501.foo(int value)` declared here
int foo(int value)
    ^
fail_compilation/ice12501.d(43): Error: function `foo` is not callable using argument types `(int, int)`
                result[i] = fun[i](result[i], r[0]);
                                  ^
fail_compilation/ice12501.d(43):        expected 1 argument(s), not 2
fail_compilation/ice12501.d(50):        `ice12501.foo(int value)` declared here
int foo(int value)
    ^
fail_compilation/ice12501.d(57): Error: template instance `ice12501.reduce!(foo, foo).reduce!(Tuple!(int, int), int[])` error instantiating
    reduce!(foo, foo)(tuple(0, 0), [ 1 ]);
                     ^
----
*/

struct Tuple(T...)
{
    alias Types = T;
    T field;
    alias field this;
}
Tuple!A tuple(A...)(A args) { return typeof(return)(args); }

template reduce(fun...)
{
    auto reduce(Args...)(Args args)
    {
        alias seed = args[0];
        alias r    = args[1];
        Args[0] result = seed;
        for (; r.length != 0; r = r[1..$])
        {
            foreach (i, Unused; Args[0].Types)
            {
                result[i] = fun[i](result[i], r[0]);
            }
        }
        return result;
    }
}

int foo(int value)
{
    return value;
}

void main()
{
    reduce!(foo, foo)(tuple(0, 0), [ 1 ]);
}
