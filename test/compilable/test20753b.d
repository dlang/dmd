struct HashCollection
{
    struct Item
    {
        IniFragment value;
    }
    Item[] items;

    ref lookupToReturnValue()
    {
        return items[0].value;
    }

    enum canDup = is(typeof(items.dup));
}
struct IniFragment
{
    HashCollection children;
}
