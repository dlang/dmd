struct S
{
    int x;

    ref S byRef(bool useRef) return
    {
        return useRef
            ? this
            : throw new Exception("byRef");
    }
}

void main()
{
    S s;

    // branch 1
    s.x = 1;
    ref s2 = s.byRef(true);
    s2.x = 2;
    assert(s2.x == 2);
    assert(s.x == 2);

    // branch 2
    auto ex = false;
    s.x = 1;
    try
    {
        ref s3 = s.byRef(false);
        s3.x = 3;
    }
    catch(Exception e)
        ex = e.msg == "byRef";
    assert(ex && s.x == 1);
}
