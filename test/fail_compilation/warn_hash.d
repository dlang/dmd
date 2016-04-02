// REQUIRED_ARGS: -wi -Werror
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/warn_hash.d(13): Warning: toHash() must be declared as extern (D) size_t toHash() const nothrow @safe, not const ulong() (-Wadvice)
---
*/

struct Key
{
    size_t toHash() const
    {
        return 1;
    }
}
