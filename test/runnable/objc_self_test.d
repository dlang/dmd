// EXTRA_OBJC_SOURCES: objc_self_test.m
// REQUIRED_ARGS: -L-framework -LFoundation

extern (C) int getValue();

void main ()
{
    assert(getValue() == 3);
}
