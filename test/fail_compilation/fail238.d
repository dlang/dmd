
template X(){}

template D(string str){}

template A(string str)
{
    static if (D!(str[str]))
    {}
    else const string A = .X!();
}

template M(alias B)
{
   const string M = A!("a");
}

void main()
{
    int q = 3;
   pragma(msg, M!(q));
}

