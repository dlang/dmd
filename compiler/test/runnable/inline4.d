import imports.inline4a;

void main()
{
    immutable baz = () => 1;
    assert(foo() == bar()());
    assert(foo() == baz());
    assert(bar()() == baz());
}
