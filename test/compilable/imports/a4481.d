module imports.a4481;

template reduce(alias pred)
{
    auto reduce(R)(R range)
    {
        return pred(range[0]);
    }
}
