/**
TEST_OUTPUT:
---
fail_compilation/ctor_self_assignment.d(16): Error: cannot initialize field `location` with itself
fail_compilation/ctor_self_assignment.d(14):        did you mean to use parameter `locaction`?
---
*/
// https://forum.dlang.org/post/teghfhpmvkdcfwfeovua@forum.dlang.org

alias Location = int;

struct Node
{
    this(Location locaction, uint f)
    {
        this.location = location;
        this.f = f;
    }

    Location location;
    uint f;
}
