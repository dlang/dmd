// REQUIRED_ARGS: -de
module test13582b;

deprecated void foo()
{
    import imports.test13582;
}

deprecated struct S
{
    import imports.test13582;
}

void main() { }
