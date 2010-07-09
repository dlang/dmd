module test;

template Test()
{
    bit opIndex(bit x)
    {
        return !x;
    }
}

void main()
{
    mixin Test!() xs;
    bit x = xs[false];
}


