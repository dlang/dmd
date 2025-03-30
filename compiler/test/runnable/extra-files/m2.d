static this()
{
    auto k = keywords;
}

immutable int[] keywords = [42];

void f()
{
    assert(keywords.ptr !is null); /* fails; should pass */
}
