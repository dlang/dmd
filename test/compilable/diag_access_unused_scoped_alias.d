// REQUIRED_ARGS: -wi -vcolumns -unittest -vunused

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_scoped_alias.d(23,5): Warning: unused local alias `Int` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(24,10): Warning: unused local manifest constant `X` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(29,13): Warning: unused private alias `Int` of public struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(30,18): Warning: unused private manifest constant `X` of public struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(35,13): Warning: unused private alias `Int` of public class, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(36,18): Warning: unused private manifest constant `X` of public class, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(39,9): Warning: unused private struct `privateStructWithPublicAlias`
compilable/diag_access_unused_scoped_alias.d(41,5): Warning: unused public alias `Int` of private struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(42,10): Warning: unused public manifest constant `X` of private struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(45,9): Warning: unused private class `privateClassWithPublicAlias`
compilable/diag_access_unused_scoped_alias.d(47,5): Warning: unused public alias `Int` of private class, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_scoped_alias.d(48,10): Warning: unused public manifest constant `X` of private class, rename to `_` or prepend `_` to name to silence
---
*/

void functionWithLocalAlias()
{
    alias Int = int;            // unused
    enum X = 42;                // unused
}

public struct publicStructWithPrivateAlias
{
    private alias Int = int;    // unused
    private enum X = 42;        // unused
}

public class publicClassWithPrivateAlias
{
    private alias Int = int;    // unused
    private enum X = 42;        // unused
}

private struct privateStructWithPublicAlias // unused
{
    alias Int = int;            // unused
    enum X = 42;                // unused
}

private class privateClassWithPublicAlias // unused
{
    alias Int = int;            // unused
    enum X = 42;                // unused
}
