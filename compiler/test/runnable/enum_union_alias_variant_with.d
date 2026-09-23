alias None = typeof(null);

enum union Option(T)
{
    case None = typeof(null);
    case Some = T;
}

void main()
{
    Option!string qualified = Option!string.Some("asdf");
    with (Option!string)
    {
        Option!string unqualified = Some("asdf");
        assert(unqualified.__tag == qualified.__tag);
    }
}