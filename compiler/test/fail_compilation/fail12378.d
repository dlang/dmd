/*
TEST_OUTPUT:
---
fail_compilation/fail12378.d(74): Error: undefined identifier `ANYTHING`
            ANYTHING-GOES
            ^
fail_compilation/fail12378.d(74): Error: undefined identifier `GOES`
            ANYTHING-GOES
                     ^
fail_compilation/fail12378.d(121):        instantiated from here: `MapResultS!((x0) => ANYTHING - GOES, Result)`
        return MapResultS!(fun, R)(r);
               ^
fail_compilation/fail12378.d(73):        instantiated from here: `mapS!(Result)`
        iota(2).mapS!(x0 =>
               ^
fail_compilation/fail12378.d(130):        instantiated from here: `__lambda_L72_C19!int`
        return fun(_input.front);
                  ^
fail_compilation/fail12378.d(121):        instantiated from here: `MapResultS!((y0) => iota(2).mapS!((x0) => ANYTHING - GOES), Result)`
        return MapResultS!(fun, R)(r);
               ^
fail_compilation/fail12378.d(72):        instantiated from here: `mapS!(Result)`
    iota(1).mapS!(y0 =>
           ^
fail_compilation/fail12378.d(84): Error: undefined identifier `ANYTHING`
            ANYTHING-GOES
            ^
fail_compilation/fail12378.d(84): Error: undefined identifier `GOES`
            ANYTHING-GOES
                     ^
fail_compilation/fail12378.d(142):        instantiated from here: `MapResultC!((x0) => ANYTHING - GOES, Result)`
        return new MapResultC!(fun, R)(r);
                   ^
fail_compilation/fail12378.d(83):        instantiated from here: `mapC!(Result)`
        iota(2).mapC!(x0 =>
               ^
fail_compilation/fail12378.d(153):        instantiated from here: `__lambda_L82_C19!int`
        return fun(_input.front);
                  ^
fail_compilation/fail12378.d(142):        instantiated from here: `MapResultC!((y0) => iota(2).mapC!((x0) => ANYTHING - GOES), Result)`
        return new MapResultC!(fun, R)(r);
                   ^
fail_compilation/fail12378.d(82):        instantiated from here: `mapC!(Result)`
    iota(1).mapC!(y0 =>
           ^
fail_compilation/fail12378.d(94): Error: undefined identifier `ANYTHING`
            ANYTHING-GOES
            ^
fail_compilation/fail12378.d(94): Error: undefined identifier `GOES`
            ANYTHING-GOES
                     ^
fail_compilation/fail12378.d(165):        instantiated from here: `MapResultI!((x0) => ANYTHING - GOES, Result)`
        return MapResultI!(fun, R).init;
               ^
fail_compilation/fail12378.d(93):        instantiated from here: `mapI!(Result)`
        iota(2).mapI!(x0 =>
               ^
fail_compilation/fail12378.d(173):        instantiated from here: `__lambda_L92_C19!int`
        return fun(_input.front);
                  ^
fail_compilation/fail12378.d(165):        instantiated from here: `MapResultI!((y0) => iota(2).mapI!((x0) => ANYTHING - GOES), Result)`
        return MapResultI!(fun, R).init;
               ^
fail_compilation/fail12378.d(92):        instantiated from here: `mapI!(Result)`
    iota(1).mapI!(y0 =>
           ^
---
*/
void testS()
{
    auto r =
    iota(1).mapS!(y0 =>
        iota(2).mapS!(x0 =>
            ANYTHING-GOES
        )
    );
}

void testC()
{
    auto r =
    iota(1).mapC!(y0 =>
        iota(2).mapC!(x0 =>
            ANYTHING-GOES
        )
    );
}

void testI()
{
    auto r =
    iota(1).mapI!(y0 =>
        iota(2).mapI!(x0 =>
            ANYTHING-GOES
        )
    );
}

auto iota(E)(E end)
{
    alias Value = E;

    static struct Result
    {
        private Value current, pastLast;

        @property inout(Value) front() inout { return current; }
    }

    return Result(0, end);
}

template mapS(fun...)
{
    auto mapS(R)(R r)
    {
        alias AppliedReturnType(alias f) = typeof(f(r.front));
        static assert(!is(AppliedReturnType!fun == void),
            "Mapping function must not return void.");

        return MapResultS!(fun, R)(r);
    }
}
struct MapResultS(alias fun, R)
{
    R _input;

    @property auto ref front()
    {
        return fun(_input.front);
    }
}

template mapC(fun...)
{
    auto mapC(R)(R r)
    {
        alias AppliedReturnType(alias f) = typeof(f(r.front));
        static assert(!is(AppliedReturnType!fun == void),
            "Mapping function must not return void.");

        return new MapResultC!(fun, R)(r);
    }
}
class MapResultC(alias fun, R)
{
    R _input;

    this(R r) { _input = r; }

    @property auto ref front()
    {
        return fun(_input.front);
    }
}

template mapI(fun...)
{
    auto mapI(R)(R r)
    {
        alias AppliedReturnType(alias f) = typeof(f(r.front));
        static assert(!is(AppliedReturnType!fun == void),
            "Mapping function must not return void.");

        return MapResultI!(fun, R).init;
    }
}
interface MapResultI(alias fun, R)
{
    static @property auto ref front()
    {
        R _input;
        return fun(_input.front);
    }
}
