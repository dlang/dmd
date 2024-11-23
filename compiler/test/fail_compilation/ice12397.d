/*
TEST_OUTPUT:
---
fail_compilation/ice12397.d(14): Error: undefined identifier `tokenLookup`
        max = tokenLookup.length
              ^
---
*/

struct DSplitter
{
    enum Token : int
    {
        max = tokenLookup.length
    }

    immutable string[Token.max] tokenText;
}
