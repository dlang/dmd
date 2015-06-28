// PERMUTE_ARGS: -unittest -debug -inline -release -g -O
import imports.a14508;

void main()
{
    // This call still won't work without linking a14508.
    //unlinked();

    version(unittest)
    {
        // Foo1!() is instantiated both in link14508 and a14508 modules.
        // Normally its codegen is skipped, however its code is conservatively
        // generated so it's defined in version(unittest).
        Foo1!() f1;
        f1.func();
        f1.test();

        // Foo2!() is instantiated only in non-root module, but it's in
        // version(unittest) block, so its code is conservatively generated.
        F2 f2;
        f2.func();
    }

    debug
    {
        // Works like Foo1!() case.
        Bar1!() b1;
        b1.func();
        b1.test();

        // Works like Foo2!() case.
        B2 b2;
        b2.func();
    }
}
