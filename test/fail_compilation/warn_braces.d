// REQUIRED_ARGS: -Werror -Wbraces
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/warn_braces.d(14): Warning: use '{ }' for an empty statement, not a ';' (-Wbraces)
fail_compilation/warn_braces.d(18): Warning: else is dangling, add { } after condition at fail_compilation/warn_braces.d(16) (-Wbraces)
---
*/

void main()
{
    ;

    if(true)
    if(true) {}
    else {}
}
