template Pack(T...)
{
    alias expand = T;

    alias opIndex(size_t index) = T[index];
    alias opSlice(size_t lower, size_t upper) = Pack!(T[lower..upper]);
    enum opDollar = T.length;
}

alias element1 = Pack!(int, double)[1]; 
alias element2 = Pack!(int, double)[$-1];

alias slice1 = Pack!(int, double, string)[1 .. $];

pragma(msg, element1);
pragma(msg, element2);

pragma(msg, slice1);
