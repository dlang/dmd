/*
REQUIRED_ARGS: -unittest
TEST_OUTPUT:
---
AliasSeq!(__unittest_L15_C5, __unittest_L19_C9, __unittest_L19_C9_1, __unittest_L15_C5_1, __unittest_L19_C9_2, __unittest_L19_C9_3)
---
*/

// Test that generated identifiers for declarations duplicated by `static foreach` are disambiguated

module staticforeach_ids;

static foreach (i; 0 .. 2)
{
    unittest { }

    static foreach (j; 0 .. 2)
    {
        unittest { }
    }
}

pragma(msg, __traits(getUnitTests, staticforeach_ids));
