// REQUIRED_ARGS: -assert=off

void main ()
{
    // If asserts are on => assert gets triggered
    // If they are off => The assert 'pass'
    int i = 42;

    assert(i == 0);
}
