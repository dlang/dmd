// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

class Outer
{
    class Inner
    {
    }
}
Outer outer;

void main()
{
    (outer).new Inner();
}
