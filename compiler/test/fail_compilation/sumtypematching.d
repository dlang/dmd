/*
TEST_OUTPUT:
---
fail_compilation/sumtypematching.d(26): Error: cannot create sumtype with element type `MoveOnly` that has a move constructor but no copy constructor
fail_compilation/sumtypematching.d(29): Error: cannot create sumtype with element type `DisabledCopy` that has a disabled copy constructor
fail_compilation/sumtypematching.d(32): Error: cannot create sumtype with element type `DisabledPostBlit` that has a disabled postblit
fail_compilation/sumtypematching.d(35): Error: sumtype variant cannot be named `tag` — it conflicts with the built-in `.tag` field
fail_compilation/sumtypematching.d(38): Error: duplicate variant name `x` in `__sumtype`
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
alias E1 = __sumtype(int | MoveOnly);

// disabled copy ctor
alias E2 = __sumtype(int | DisabledCopy);

// disabled postblit
alias E3 = __sumtype(int | DisabledPostBlit);

// variant named "tag" conflicts with built-in .tag field
alias E4 = __sumtype(int tag | bool);

// duplicate variant names
alias E5 = __sumtype(int x | bool x);
