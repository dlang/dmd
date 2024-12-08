/*
TEST_OUTPUT:
---
fail_compilation/parseStc.d(37): Error: missing closing `)` after `if (x`
    if (x; 1) {}
         ^
fail_compilation/parseStc.d(37): Error: use `{ }` for an empty statement, not `;`
    if (x; 1) {}
         ^
fail_compilation/parseStc.d(37): Error: found `)` when expecting `;` following expression
    if (x; 1) {}
            ^
fail_compilation/parseStc.d(37):        expression: `1`
    if (x; 1) {}
           ^
fail_compilation/parseStc.d(38): Error: redundant attribute `const`
    if (const const auto x = 1) {}
              ^
fail_compilation/parseStc.d(43): Error: redundant attribute `const`
    const const x = 1;
          ^
fail_compilation/parseStc.d(44): Error: redundant attribute `const`
    foreach (const const x; [1,2,3]) {}
                   ^
fail_compilation/parseStc.d(45): Error: conflicting attribute `immutable`
    foreach (const immutable x; [1,2,3]) {}
                   ^
fail_compilation/parseStc.d(48): Error: redundant attribute `const`
struct S3 { const const test3() {} }
                  ^
fail_compilation/parseStc.d(49): Error: redundant attribute `const`
void test4(const const int x) {}
                 ^
---
*/
void test1() {
    if (x; 1) {}
    if (const const auto x = 1) {}
}

void test2()
{
    const const x = 1;
    foreach (const const x; [1,2,3]) {}
    foreach (const immutable x; [1,2,3]) {}
}

struct S3 { const const test3() {} }
void test4(const const int x) {}
