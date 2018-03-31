// https://issues.dlang.org/show_bug.cgi?id=18688

class A
{
    this(int x){}
    @disable this();
}

class B: A
{
    this(int x)
    {
        super(x);
    }

    this(string b)
    {
        switch(b)
        {
            case "a":break;
            default: assert(false);
        }
        this(1);
    }
}

class C: A
{
    this(int x)
    {
        super(x);
    }

    this(string b)
    {
        switch(b)
        {
            case "a":break;
            default: assert(false);
        }
        super(1);
    }
}
