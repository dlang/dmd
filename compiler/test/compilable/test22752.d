/*
REQUIRED_ARGS:
PERMUTE_ARGS:
*/

struct S
{
    int isnot;
    int[] arguments;
}

struct Array(T)
{
    static if (is(const(T) : T))
    {
        void insert()
        {
            static assert (is(const(T) : T));
        }
    }
}

alias A = Array!S;
