// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/fail13775.d(25): Error: cannot cast expression `ubytes[0..2]` of type `ubyte[2]` to `ubyte[1]`
    auto ng1 = cast(ubyte[1]) ubytes[0 .. 2];   // ubyte[2] to ubyte[1]
                                    ^
fail_compilation/fail13775.d(26): Error: cannot cast expression `ubytes[0..2]` of type `ubyte[2]` to `ubyte[3]`
    auto ng2 = cast(ubyte[3]) ubytes[0 .. 2];   // ubyte[2] to ubyte[3]
                                    ^
fail_compilation/fail13775.d(27): Error: cannot cast expression `ubytes[0..2]` of type `ubyte[2]` to `byte[1]`
    auto ng3 = cast( byte[1]) ubytes[0 .. 2];   // ubyte[2] to  byte[1]
                                    ^
fail_compilation/fail13775.d(28): Error: cannot cast expression `ubytes[0..2]` of type `ubyte[2]` to `byte[3]`
    auto ng4 = cast( byte[3]) ubytes[0 .. 2];   // ubyte[2] to  byte[3]
                                    ^
---
*/

void main()
{
    ubyte[4] ubytes = [1,2,3,4];

    // CT-known slicing succeeds but sizes cannot match
    auto ng1 = cast(ubyte[1]) ubytes[0 .. 2];   // ubyte[2] to ubyte[1]
    auto ng2 = cast(ubyte[3]) ubytes[0 .. 2];   // ubyte[2] to ubyte[3]
    auto ng3 = cast( byte[1]) ubytes[0 .. 2];   // ubyte[2] to  byte[1]
    auto ng4 = cast( byte[3]) ubytes[0 .. 2];   // ubyte[2] to  byte[3]
}
