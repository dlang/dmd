alias aliases(a...) = a;

template sort(alias f, a...)
{
    static if (a.length > 0) // (1)
    {
        alias x = f!(a[1]);
        alias sort = a;
    }
    else
        alias sort = a;
}

alias SortedItems = sort!(isDependencyOf, Top, String); // (2)
//pragma (msg, "1: ", SortedItems);

enum isDependencyOf(Item) = Item.DirectDependencies.length == 0;

struct Top
{
    alias DirectDependencies = aliases!();
}

struct String
{
    alias DirectDependencies = aliases!();
    
    //pragma(msg, "2: ", SortedItems);
    enum l = SortedItems.length; // (3)
    static assert(is(typeof(SortedItems.length) == size_t)); // (4)
}
