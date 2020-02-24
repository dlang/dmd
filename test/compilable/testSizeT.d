string typename(T)(T t)
{
    return typeof(t).stringof;
}


static assert(size_t.stringof == "size_t");

static assert(() {
    size_t x;
    return typename(x);
} () == "size_t");
