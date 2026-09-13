// https://github.com/dlang/dmd/issues/23239
// static assert instantiating a template with static this()
// should not eliminate the static this() as dead code
// when the template is also used at runtime.

template Tmpl()
{
    int data;
    template touch(T)
    {
        static this() { data = T.sizeof; }
        enum touch = true;
    }
}

int main()
{
    static assert(Tmpl!().touch!int);   // CTFE instantiation
    assert(Tmpl!().data == 4);          // runtime use, static this() must have run
    return 0;
}
