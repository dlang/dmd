Foo foo(A...)()
{
}

static assert(foo!(1, 2)());
