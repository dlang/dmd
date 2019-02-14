// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/deprecated19402.d(18): Deprecation: unpromoted result of `<<` due to implicit `cast(int)urhs`
fail_compilation/deprecated19402.d(19): Deprecation: unpromoted result of `>>` due to implicit `cast(int)urhs`
fail_compilation/deprecated19402.d(20): Deprecation: unpromoted result of `>>>` due to implicit `cast(int)urhs`
fail_compilation/deprecated19402.d(23): Deprecation: unpromoted result of `<<` due to implicit `cast(int)srhs`
fail_compilation/deprecated19402.d(24): Deprecation: unpromoted result of `>>` due to implicit `cast(int)srhs`
fail_compilation/deprecated19402.d(25): Deprecation: unpromoted result of `>>>` due to implicit `cast(int)srhs`
---
*/

void main()
{
    ulong urhs;
    uint a1 = 1u << urhs;
    uint a2 = 1u >> urhs;
    uint a3 = 1u >>> urhs;

    long srhs;
    int a4 = 1 << srhs;
    int a5 = 1 >> srhs;
    int a6 = 1 >>> srhs;
}
