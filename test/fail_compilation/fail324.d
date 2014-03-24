/*
test_output:
---
fail_compilation/fail324.d(11): Error: need 'this' for 'f' of type 'int'
fail_compilation/fail324.d(18): Error: template instance fail324.main.doStuff!((i)
{
return j;
}
) error instantiating
---
*/

struct Foo
{
    int f;
    void doStuff(alias fun)() { fun(f); }
}

void main()
{
    Foo foo;
    int j;
    foo.doStuff!( (i) { return j; })();
}
