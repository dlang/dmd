module issue20439;
import issue20439a;

// This module independently bakes the `.init` images of S and T (and the CTFE instances
// embedded in them). Before the fix, the backing `internal` symbols were cached on the
// shared AST nodes and emitted only into the first object module, so this module's object
// file held only undefined references to symbols it never defines.
__gshared S s;
__gshared T t;

void main()
{
    assert(s.c !is null && s.c.x == 42);
    assert(t.p !is null && t.p.y == 7);
}
