// Based upon the fail_compilation/ice4094.d test case,
//  adds a pointer into the cyclic dependencies,
//  which should break the cycle.

struct Zug(int Z)
{
    // Pointer to Bug4094 - size is known without analyzing Bug4094's fields
    Bug4094!(0)* hof;
    int bahn;

    // Make sure we can still access the enum, even though hof wasn't fully analyzed.
    static assert(hof.GrabIt == 99);
}

struct Bug4094(int Q)
{
    // Direct containment of Zug - this is fine because Zug contains Bug4094*,
    // not Bug4094 directly (indirection breaks the cycle)
    Zug!(0) zug;

    enum GrabIt = 99;
}

// We don't actually need to run this.
void main()
{
    Zug!(0) z;
}
