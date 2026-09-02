/*
TEST_OUTPUT:
---
fail_compilation/sumtypematching.d(32): Error: cannot create sumtype with element type `MoveOnly` that has a move constructor but no copy constructor
fail_compilation/sumtypematching.d(35): Error: cannot create sumtype with element type `DisabledCopy` that has a disabled copy constructor
fail_compilation/sumtypematching.d(38): Error: cannot create sumtype with element type `DisabledPostBlit` that has a disabled postblit
fail_compilation/sumtypematching.d(41): Error: sumtype variant cannot be named `tag` — it conflicts with the built-in `.tag` field
fail_compilation/sumtypematching.d(44): Error: duplicate variant name `x` in `__sumtype`
fail_compilation/sumtypematching.d(47): Error: sumtype cannot have more than one integer variant — found `int` and `long`
fail_compilation/sumtypematching.d(62): Error: forward reference to inferred return type of function call `traverse(__SumType3(cast(ubyte)0u, __matchArm6.left, ))`
fail_compilation/sumtypematching.d(60): Error: cannot analyze match arm body for variant `Branch`
fail_compilation/sumtypematching.d(66):        while evaluating: `static assert(is(typeof(traverse(Node.init)) == int))`
fail_compilation/sumtypematching.d(72): Error: cannot unify integer types `long` and `ulong` — no wider signed type available
fail_compilation/sumtypematching.d(78):        while evaluating: `static assert(!is(typeof(matchOverflow(OverflowSrc.init))))`
---
*/

struct MoveOnly { int x; this(return MoveOnly other) { x = other.x; } }
struct DisabledCopy {
    int x;
    @disable this(ref DisabledCopy);
    this(int v) { x = v; }
}
struct DisabledPostBlit {
    int x;
    @disable this(this);
}

// All of these should produce compile errors:

// move ctor, no copy ctor
__sumtype E1 = int | MoveOnly;

// disabled copy ctor
__sumtype E2 = int | DisabledCopy;

// disabled postblit
__sumtype E3 = int | DisabledPostBlit;

// variant named "tag" conflicts with built-in .tag field
__sumtype E4 = int tag | bool;

// duplicate variant names
__sumtype E5 = int x | bool x;

// more than one integer variant is not allowed
__sumtype E6 = int | long;

struct Leaf {
    int value;
}

struct Branch {
    Leaf left;
}

__sumtype Node = Leaf | Branch;

auto traverse(Node n) {
    return n.match {
        (Leaf l) => l.value,
        (Branch b) => traverse(Node(b.left))
    };
}

static assert(is(typeof(traverse(Node.init)) == int));

// Match expression result with long + ulong arms should fail (no wider signed type)
__sumtype OverflowSrc = long | string;

auto matchOverflow(OverflowSrc s) {
    return s.match {
        (long x) => x,
        (string y) => cast(ulong) y.length
    };
}

static assert(!is(typeof(matchOverflow(OverflowSrc.init))));
