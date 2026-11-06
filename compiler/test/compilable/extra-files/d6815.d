void d()
{
    import e6815 : e, e2;
    static if (e("")) { }

    static if (e2(""))
    {
        pragma(msg, "good");
    }
    else
    {
        pragma(msg, "bad");
    }
}
