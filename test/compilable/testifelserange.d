import std.traits : Unqual;
alias Tuple(T...) = T;

void test(T,int Q)(bool unknown)
{
    static if (Q)
    {
      Unqual!T ii = unknown ? 33 : -1;
      T i = ii;
    }
    else
    {
      T i = unknown ? -1 : 33;
    }

    if (i)
    {
      static assert(Q || i >= -1);
      static assert(Q || i <= 33);
    }
    else
    {
      static assert(i == 0);
    }

    if (i == 33)
    {
      static assert(i == 33);
    }
    else
    {
      static assert(Q || i >= -1);
      static assert(Q || i <= 32);
    }

    if (i != 33)
    {
      static assert(Q || i >= -1);
      static assert(Q || i <= 32);
    }
    else
    {
      static assert(i == 33);
    }

    if (10 <= i)
    {
      static assert(i >= 10);
      static assert(i <= (Q?T.max:33));
    }
    else
    {
      static assert(i >= (Q?T.min:-1));
      static assert(i <= 9);
    }

    if (i > 10)
    {
      static assert(i >= 11);
      static assert(i <= (Q?T.max:33));
    }
    else
    {
      static assert(i >= (Q?T.min:-1));
      static assert(i <= 10);
    }

    if (!i)
    {
      static assert(i == 0);
    }
    else
    {
      static assert(Q || i >= -1);
      static assert(Q || i <= 33);
    }
}

void main(string[] args)
{
    test!(immutable int, 0)(args.length < 1);
    test!(const int, 0)(args.length < 1);
    test!(immutable(int), 0)(args.length < 1);
    test!(const(int), 0)(args.length < 1);

    test!(immutable int, 1)(args.length < 1);
    test!(const int, 1)(args.length < 1);
    test!(immutable(int), 1)(args.length < 1);
    test!(const(int), 1)(args.length < 1);
}
