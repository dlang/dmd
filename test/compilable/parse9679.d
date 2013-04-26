void test9679(inout int = 0)
{
    if (        auto n = 1) { static assert(is(typeof(n) ==              int)); }
    if (       const n = 1) { static assert(is(typeof(n) ==        const int)); }
    if (   immutable n = 1) { static assert(is(typeof(n) ==    immutable int)); }
    if (shared       n = 1) { static assert(is(typeof(n) == shared       int)); }
    if (shared const n = 1) { static assert(is(typeof(n) == shared const int)); }
    if (       inout n = 1) { static assert(is(typeof(n) ==        inout int)); }
    if (shared inout n = 1) { static assert(is(typeof(n) == shared inout int)); }

    if (       const int n = 1) { static assert(is(typeof(n) ==        const int)); }
    if (   immutable int n = 1) { static assert(is(typeof(n) ==    immutable int)); }
    if (shared       int n = 1) { static assert(is(typeof(n) == shared       int)); }
    if (shared const int n = 1) { static assert(is(typeof(n) == shared const int)); }
    if (       inout int n = 1) { static assert(is(typeof(n) ==        inout int)); }
    if (shared inout int n = 1) { static assert(is(typeof(n) == shared inout int)); }

    if (       const(int) n = 1) { static assert(is(typeof(n) ==        const int)); }
    if (   immutable(int) n = 1) { static assert(is(typeof(n) ==    immutable int)); }
    if (shared      (int) n = 1) { static assert(is(typeof(n) == shared       int)); }
    if (shared const(int) n = 1) { static assert(is(typeof(n) == shared const int)); }
    if (       inout(int) n = 1) { static assert(is(typeof(n) ==        inout int)); }
    if (shared inout(int) n = 1) { static assert(is(typeof(n) == shared inout int)); }

    if (immutable(int)[] n = [1]) { static assert(is(typeof(n) == immutable(int)[])); }
}
