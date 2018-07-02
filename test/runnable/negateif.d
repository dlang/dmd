void main()
{
    if !(0) {}
    else assert(0);

    if !(1)
        assert(0);

    if !(1 * 100)
        assert(0);

    enum foo = true;
    if !(foo || false)
        assert(0);
}
