//REQUIRED_ARGS: -allinst
template Tuple(Specs)
{
    struct Tuple
    {
        this()
        {
        }

        ref opAssign(R)(R )
        if (isTuple!R)
        {
        }
    }
}

enum isTuple(T) = __traits(compiles,
                           {
                               void f(Specs)(Specs ) {}
                               f(T.init);
                           } );

pragma(msg, is(Tuple!int));
