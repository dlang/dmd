/*
TEST_OUTPUT:
---
fail_compilation/fail12385.d(27): Error: cannot modify immutable expression BundledState("bla", 3).x
---
*/

class BundledState
{
    string m_State;

    int x = 3;

    this(string state) immutable
    {
        m_State = state;
    }
}

enum States : immutable(BundledState)
{
    unbundled = new immutable BundledState("bla"),
}

void main(string[] argv)
{
    States.unbundled.x = 6; // Modifies x.
}
