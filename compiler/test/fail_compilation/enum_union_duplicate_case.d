/*
TEST_OUTPUT:
---
fail_compilation/enum_union_duplicate_case.d(16): Error: duplicate case `StructVariant` in enum union `enum_union_duplicate_case.Test1`
fail_compilation/enum_union_duplicate_case.d(23): Error: duplicate case `ExternalStruct` in enum union `enum_union_duplicate_case.Test2`
fail_compilation/enum_union_duplicate_case.d(30): Error: duplicate case `ExternalStruct` in enum union `enum_union_duplicate_case.Test3`
fail_compilation/enum_union_duplicate_case.d(37): Error: duplicate case `StructVariant` in enum union `enum_union_duplicate_case.Test4`
fail_compilation/enum_union_duplicate_case.d(44): Error: duplicate case `Variant1` in enum union `enum_union_duplicate_case.Test5`
fail_compilation/enum_union_duplicate_case.d(51): Error: duplicate case `double` in enum union `enum_union_duplicate_case.Test6`
---
*/

struct ExternalStruct {}

// 1. Two record variants sharing the same name and identical bodies
enum union Test1
{
    case StructVariant {};
    case StructVariant {};
}

// 2. Bare type vs positional variant with the same name
enum union Test2
{
    case ExternalStruct;
    case ExternalStruct(int, string);
}

// 3. Bare type vs unit variant with the same name
enum union Test3
{
    case ExternalStruct;
    case ExternalStruct();
}

// 4. Same variant name reused with different record fields
enum union Test4
{
    case StructVariant { int id; };
    case StructVariant { string s; };
}

// 5. Same name reused across different variant kinds (record vs positional)
enum union Test5
{
    case Variant1 { int id; };
    case Variant1(int);
}

// 6. Duplicate bare type
enum union Test6
{
    case double;
    case double;
}
