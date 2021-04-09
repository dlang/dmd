module linkdebug_primitives;

size_t popBackN(R)(ref R r, size_t n)
{
    n = cast(size_t) (n < r.length ? n : r.length);
    r = r[0 .. $ - n];
    return n;
}

auto moveAt(R, I)(R r, I i)
{
    return r[i];
}
