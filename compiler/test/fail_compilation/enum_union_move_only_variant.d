/*
TEST_OUTPUT:
---
fail_compilation/enum_union_move_only_variant.d(18): Error: cannot create enum union with element type `MoveOnly` that has a move constructor but no copy constructor
---
*/

// A payload type with a move constructor but no copy constructor cannot be
// stored in an enum union: ordinary copies of the enum union (assignment,
// pass-by-value) would raw-bitcopy the payload union instead of invoking the
// move constructor, leading to double-destruction of the payload.
struct MoveOnly
{
    int x;
    this(return MoveOnly other) { x = other.x; }
}

enum union WithMoveOnly
{
    case Moved(MoveOnly),
    case Other(bool),
}
