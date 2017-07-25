import core.stdc.stdio;

__gshared bool bgEnable = 1;

void smallAlloc() nothrow
{
    fullcollect();
}

size_t fullcollect() nothrow
{
    if(bgEnable)
       return fullcollectTrigger();

    return fullcollectNow();
}

size_t fullcollectNow() nothrow
{
    if (bgEnable)
        assert(0);
    pragma(inline, false);
    return 1;
}

size_t fullcollectTrigger() nothrow
{
    pragma(inline, false);
    return 0;
}

void main()
{
    smallAlloc();
}
