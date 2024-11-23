/*
TEST_OUTPUT:
---
fail_compilation/ice13816.d(23): Error: template instance `TypeTuple!(ItemProperty!())` recursive template expansion
        alias ItemProperty = TypeTuple!(ItemProperty!());
                             ^
fail_compilation/ice13816.d(23): Error: alias `ice13816.ItemProperty!().ItemProperty` recursive alias declaration
        alias ItemProperty = TypeTuple!(ItemProperty!());
        ^
fail_compilation/ice13816.d(28): Error: template instance `ice13816.ItemProperty!()` error instantiating
    alias items = ItemProperty!();
                  ^
---
*/


alias TypeTuple(T...) = T;

template ItemProperty()
{
    static if (true)
    {
        alias ItemProperty = TypeTuple!(ItemProperty!());
    }
}
void main()
{
    alias items = ItemProperty!();

    enum num = items.length;
}
