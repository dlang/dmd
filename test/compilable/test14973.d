/+
template map(fun...)
{
    auto map(R)(R r)
    {
        return MapResult!(fun, R)(r);
    }
}

struct MapResult(alias fun, R)
{
    R _input;

    @property bool empty() { return _input.length == 0; }
    @property auto front() { return fun(_input[0]); }
    void popFront() { _input = _input[1..$]; }
}

class Foo
{
    int baz() { return 1; }
    void bar()
    {
        auto s = [1].map!(i => baz()); // compiles
        auto r = [1].map!(
            // lambda1
            i =>
                [1].map!(
                    // lambda2
                    j =>
                        baz()
                )
        ); // compiles <- error
    }
}

class Bar
{
    int baz;
    void bar()
    {
        auto s = [1].map!(i => baz); // compiles
        auto r = [1].map!(
            // lambda1
            i =>
                [1].map!(
                    // lambda2
                    j =>
                        baz
                )
        ); // compiles <- error
    }
}
+/
void main() {}
