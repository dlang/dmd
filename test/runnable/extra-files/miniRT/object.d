module object;

class Object
{
}

version(D_LP64 )
    alias size_t = ulong;
else
    alias size_t = uint;
alias string = immutable(char)[];
