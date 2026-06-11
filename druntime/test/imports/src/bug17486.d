version (Windows)
{
    import core.sys.windows.mmsystem;

    static assert(WAVEHDR.alignof == (void*).alignof);
}
else
{
}
