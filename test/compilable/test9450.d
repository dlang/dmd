// REQUIRED_ARGS: -release
void main()
{
    version (assert) assert(foo());  // ok
    assert(foo);  // should work
}

version (assert)
{
    bool foo()
    {
        return true;
    }
}
