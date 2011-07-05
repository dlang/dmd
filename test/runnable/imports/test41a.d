module imports.test41a;

void foo()
{
        assert(false, "GO");
}

int i; // make func impure so it is not ctfed away
public void func(T)()
{
        assert(i, "Blah");
}

