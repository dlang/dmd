// EXTRA_FILES: imports/ice11054a.d
import imports.ice11054a;

static assert(!__traits(compiles, tuple()));

E[] appender(A : E, E)()
{
    return E;
}
