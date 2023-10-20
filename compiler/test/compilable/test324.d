/* TEST_OUTPUT:
---
compilable/test324.d(17): Deprecation: function `test324.main.doStuff!((i)
{
return i;
}
).doStuff` function requires a dual-context, which is deprecated
compilable/test324.d(23):        instantiated from here: `doStuff!((i)
{
return i;
}
)`
---
*/
struct Foo
{
    void doStuff(alias fun)() {}
}

void main()
{
    Foo foo;
    foo.doStuff!( (i) { return i; })();
}
