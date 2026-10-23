struct mydata
{
    int a, b, c;
}

bool check(mydata* p)
{
    return p.a == 1 && p.b == 2 && p.c == 3;
}

void testNoMsg()
{
    mydata data;
    assert(check(&data));
}

void testWithMsg()
{
    mydata data;
    assert(check(&data), "custom assert message");
}

void main(string[] args)
{
    if (args.length > 1 && args[1] == "msg")
        testWithMsg();
    else
        testNoMsg();
}
