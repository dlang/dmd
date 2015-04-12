module imports.prot5770;

public
{
    void publicF() {}
    void publicTF()() {}
}
package
{
    void packageF() {}
    void packageTF()() {}
}
private
{
    void privateF() {}
    void privatebar()() {}
}

class C
{
    public
    {
        void publicF() {}
        void publicTF()() {}
    }
    protected
    {
        void protectedF() {}
        void protectedTF()() {}
    }
    package
    {
        void packageF() {}
        void packageTF()() {}
    }
    private
    {
        void privateF() {}
        void privateTF()() {}
    }
}

struct S
{
    public
    {
        void publicF() {}
        void publicTF()() {}
    }
    protected
    {
        void protectedF() {}
        void protectedTF()() {}
    }
    package
    {
        void packageF() {}
        void packageTF()() {}
    }
    private
    {
        void privateF() {}
        void privateTF()() {}
    }
}
