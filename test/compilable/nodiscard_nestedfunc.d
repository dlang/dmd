@nodiscard int outer()
{
    int inner() { return 0; }
    inner();
    return 0;
}
