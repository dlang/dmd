// The runtime must not initialize the GC at termination
// when the program never allocated.
import core.memory : GC;

shared static ~this()
{
    // runs after all thread-local module destructors
    assert(GC.stats().usedSize == 0);
}

void main()
{
}
