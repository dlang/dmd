extern(C++) @system {
    template Foo(T) {
        static int boo();
    }
}

void main()
{
    string s = Foo!(int).boo.mangleof;
}
