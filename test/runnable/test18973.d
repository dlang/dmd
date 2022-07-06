struct X {
    @disable size_t toHash() const;
    @disable string toString() const;
    @disable bool opEquals(const ref X) const;
    @disable int opCmp(const ref X) const;
}

void main ()
{
    // This is a runnable test as we are testing a linker error
}
