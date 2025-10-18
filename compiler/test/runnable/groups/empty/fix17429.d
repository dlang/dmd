class Klazz
{
    __gshared size_t count;
    ~this()
    {
        ++count;
    }
}

shared static this()
{
    auto s = new Klazz;
    {
        scope s2 = s; // calls delete even though it does not own s
    }
    assert(Klazz.count == 0);
}
