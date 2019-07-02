void main()
{
    const x = 0;
    assert(&x == &(cast() x)); // fails; lowered to `assert(& x is &0)`
}
