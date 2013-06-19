extern(C++)
{
    struct S
    {
        void foo(int) const;
        void bar(int);
        static __gshared int boo;
    }
}

version (OSX)
{
    static assert(S.foo.mangleof == "__ZNK1S3fooEi");
    static assert(S.bar.mangleof == "__ZN1S3barEi");
    static assert(S.boo.mangleof == "__ZN1S3booE");
}
else version (Posix)
{
    static assert(S.foo.mangleof == "_ZNK1S3fooEi");
    static assert(S.bar.mangleof == "_ZN1S3barEi");
    static assert(S.boo.mangleof == "_ZN1S3booE");
}
