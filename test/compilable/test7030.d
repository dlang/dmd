extern(C++)
{
    struct S
    {
        void foo(int) const;
        void bar(int);
    }
}

version (OSX)
{
    static assert(S.foo.mangleof == "__ZNK1S3fooEi");
    static assert(S.bar.mangleof == "__ZN1S3barEi");
}
else version (Posix)
{
    static assert(S.foo.mangleof == "_ZNK1S3fooEi");
    static assert(S.bar.mangleof == "_ZN1S3barEi");
}
