module imports.test20392a;

void f()
{
    static assert(0, "-deps should not analyze function bodies of imported modules");
}
